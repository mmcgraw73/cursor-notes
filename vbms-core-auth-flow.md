# VBMS Core End-to-End Authentication & Authorization Flow

> Tracing a single request from browser to database — every redirect, cookie, and token at each hop.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Component Inventory](#2-component-inventory)
3. [Current Flow: SiteMinder (Production)](#3-current-flow-siteminder-production)
4. [New Flow: Entra + Apache (In Development)](#4-new-flow-entra--apache-in-development)
5. [Hop-by-Hop: VBMS Core → Keycloak (SAML)](#5-hop-by-hop-vbms-core--keycloak-saml)
6. [Hop-by-Hop: Keycloak → IDP Proxy (OIDC Broker)](#6-hop-by-hop-keycloak--idp-proxy-oidc-broker)
7. [Hop-by-Hop: IDP Proxy → CSS (SOAP)](#7-hop-by-hop-idp-proxy--css-soap)
8. [Token Cascade Back: CSS → IDP Proxy → Keycloak → VBMS Core](#8-token-cascade-back-css--idp-proxy--keycloak--vbms-core)
9. [SAML Response Processing in VBMS Core](#9-saml-response-processing-in-vbms-core)
10. [XACML Authorization (PDP/PIP)](#10-xacml-authorization-pdppip)
11. [Cookies & Sessions at Every Hop](#11-cookies--sessions-at-every-hop)
12. [Token/Claim Mapping Chain](#12-tokenclaim-mapping-chain)
13. [Timeout & Expiry Reference](#13-timeout--expiry-reference)
14. [Sequence Diagram](#14-sequence-diagram)

---

## 1. Architecture Overview

VBMS Core's authentication spans **five systems** talking **three protocols**:

```
┌─────────┐  SAML   ┌──────────┐  OIDC   ┌───────────┐  SOAP   ┌─────┐
│VBMS Core│◄───────►│ Keycloak │◄───────►│ IDP Proxy │───────►│ CSS │
│(WebLogic)│        │(idp realm)│        │(Spring Boot)│       │(VA) │
└─────────┘        └──────────┘        └───────────┘       └─────┘
     ▲                   ▲                    ▲
     │                   │                    │
  Browser            Browser              SiteMinder
  (cookies)          (redirect)           or Apache/Entra
```

| Protocol | Between | Purpose |
|----------|---------|---------|
| **SAML 2.0** | VBMS Core ↔ Keycloak | SP-initiated SSO, assertion with user attributes |
| **OIDC** | Keycloak ↔ IDP Proxy | Identity broker, authorization code flow |
| **SOAP** | IDP Proxy → CSS | User lookup (security profile, roles, stations) |
| **XACML** | Inside VBMS Core | Attribute-based access control (user vs veteran) |

---

## 2. Component Inventory

### VBMS Core (Service Provider)
- **Runtime**: WebLogic, Java, Spring Security SAML Extension (OpenSAML v2)
- **Entity ID**: `https://vbms-core-dev.dev.bip.va.gov/vbmsp2` (P2 Claims)
- **ACS Endpoint**: `/saml/SSO` (via `SAMLProcessingFilter`)
- **SP Keystore**: `vbms-claims-sso.jks`, alias `vbms-sp-claims01-v1`
- **IdP Metadata**: Static classpath resource (`idp-bipsso-claims01.xml`)
- **User Details**: `VbmsSamlUsersDetailsService.loadUserBySAML()` → `SecurityUser`
- **Authorization**: Sun XACML PDP with 41 policy sets, 24 PIP modules

### Keycloak (Identity Broker)
- **Realm**: `idp`
- **VBMS Core Client**: SAML protocol, entity ID matches SP
- **Browser Flow**: `browser-eks` → `auth-cookie` (ALTERNATIVE) → `identity-provider-redirector` (ALTERNATIVE, default to `vba-proxy-eks`)
- **IDP Broker**: `vba-proxy-eks` — OIDC provider pointing to IDP Proxy
- **SAML Mappers**: 8 attribute mappers (securityLevel, stationId, subjectId, authorities, etc.)
- **IDP Broker Mappers**: 6 claim-to-attribute mappers

### IDP Proxy (`bip-security-idpproxy`)
- **Runtime**: Spring Boot, Spring Authorization Server
- **OIDC Client ID**: `bip`
- **Context Path**: `/ssoi` (dev), `/sso` (local/int)
- **Redirect URI**: `https://bss-{env}.dev.bip.va.gov/auth/realms/idp/broker/vba-proxy-eks/endpoint`
- **CSS System Account**: `VBMSSYSACCT` at station `283`
- **JWT Signing**: RSA 2048-bit (ephemeral, regenerated on restart)
- **IAM Headers**: SSOi (`ADSAMACCOUNTNAME`), SSOe (`va_eauth_pid`), Entra (`OIDC_CLAIM_email` — planned)

### CSS (Common Security Service)
- **Endpoint**: `http://bepdev.vba.va.gov/css-webservices/CommonSecurityServiceImplWSV1`
- **Operations**: `getSecurityProfileFromContext`, `getCssUserStationsByApplicationUsername`
- **Authentication**: System account (`VBMSSYSACCT`) in SSL-wrapped SOAP call
- **Returns**: `CssSecurityProfile` (participantId, secLevel, roles/functions, stationId, name, email)

### Apache / mod_auth_openidc (New — Entra Flow)
- **Provider**: VA Entra ID (Azure AD) tenant `e95f1b23-abaf-45ee-821d-b7ab251ab3bf`
- **Client ID**: `85d12a62-b5b4-489e-80a2-65df76078956`
- **Scope**: `openid email` (not `profile` — exceeds 4KB cookie limit)
- **Callback**: `https://bss-entra.dev.bip.va.gov/ssoi/callback`
- **Session Cookie**: `mod_auth_openidc_session` (AES-SIV encrypted)
- **Output Header**: `OIDC_CLAIM_email` → forwarded to IDP Proxy

---

## 3. Current Flow: SiteMinder (Production)

```
Browser → VBMS Core (no session)
    → 302 to Keycloak /auth/realms/idp/protocol/saml (SAML AuthnRequest)
        → Keycloak (no session) → auto-redirect to vba-proxy-eks
            → 302 to IDP Proxy /ssoi/oauth2/authorize?client_id=bip
                → IDP Proxy (no IAM headers) → pass-through to SiteMinder
                    → 302 to SiteMinder Central Login
                        → User inserts PIV/CAC → authenticates
                    → SiteMinder sets SM cookies
                → IDP Proxy receives IAM headers (ADSAMACCOUNTNAME, etc.)
                → IDP Proxy calls CSS SOAP → gets security profile
                → IDP Proxy generates auth code → 302 to Keycloak broker endpoint
            → Keycloak exchanges code for OIDC tokens
            → Keycloak calls /userinfo → gets user attributes
            → Keycloak maps OIDC claims → user attributes → SAML assertion attributes
        → Keycloak POSTs SAML Response to VBMS Core /saml/SSO
    → VbmsSamlUsersDetailsService.loadUserBySAML() → SecurityUser
    → HTTP session created → 302 to original URL
```

**Hops**: 5+ redirects, 2–5 seconds if already logged in to SiteMinder.

---

## 4. New Flow: Entra + Apache (In Development)

```
Browser → nginx → Apache (no mod_auth_openidc session)
    → 302 to Entra ID /oauth2/v2.0/authorize
        → User authenticates (Azure AD, Conditional Access, MFA)
    → 302 to Apache /ssoi/callback?code=<auth_code>
        → Apache: code → token exchange (server-side POST to Entra)
        → Apache: validates ID token, extracts email claim
        → Apache: creates encrypted session cookie
        → Apache: sets OIDC_CLAIM_email header → proxies to IDP Proxy
    → IDP Proxy receives OIDC_CLAIM_email header
    → IDP Proxy calls CSS SOAP → gets security profile
    → (continues same as SiteMinder flow from IDP Proxy onward)
```

**Hops**: 4 redirects, 1–2 seconds if already logged in to Entra.

**Key difference**: Apache handles the external identity provider directly; no SiteMinder web agent in the chain.

> **Note**: `OIDC_CLAIM_email` header processing is not yet implemented in the IDP Proxy codebase. The current `IAMParser.java` only handles SSOi and SSOe headers. This is POC-stage.

---

## 5. Hop-by-Hop: VBMS Core → Keycloak (SAML)

### 5.1 Trigger: No Session

User requests `https://vbms-core-dev.dev.bip.va.gov/vbmsp2/workQueueInbox`. Spring Security's `<http>` block finds no authenticated session → invokes `SAMLEntryPoint`.

### 5.2 SAML AuthnRequest Generation

`SAMLEntryPoint` generates a SAML `<AuthnRequest>`:

| Field | Value |
|-------|-------|
| Issuer | `https://vbms-core-dev.dev.bip.va.gov/vbmsp2` (SP entity ID) |
| Destination | `https://bss-{env}.dev.bip.va.gov/auth/realms/idp/protocol/saml` |
| AssertionConsumerServiceURL | `https://vbms-core-dev.dev.bip.va.gov/vbmsp2/saml/SSO` |
| ProtocolBinding | `urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST` |
| IncludeScoping | `false` |
| Signed | `true` (P2 production) / `false` (default) |

### 5.3 Binding

Request sent via **HTTP-Redirect** (GET with deflated, base64-encoded AuthnRequest in query param) or **HTTP-POST** (form auto-submit) binding.

### 5.4 SAML Filter Chain in VBMS Core

```
Request
  │
  ├─ MetadataKeyInfoGeneratorFilter  (FIRST — fixes OpenSAML/WSS4J bootstrap conflict)
  ├─ MetadataGeneratorFilter         (after FIRST — auto-generates SP metadata)
  ├─ FilterChainProxy (samlFilter):
  │    /saml/login/**    → SAMLEntryPoint
  │    /saml/SSO/**      → SAMLProcessingFilter (ACS)
  │    /saml/metadata/** → MetadataDisplayFilter
  │    /saml/logout/**   → LogoutFilter → SamlLogoutHandler
  │    /saml/SingleLogout/** → SAMLLogoutProcessingFilter
  ├─ UnauthenticatedFilter (before ANONYMOUS — audit logging)
  ├─ OAuthSessionFilter (after EXCEPTION_TRANSLATION)
  └─ ContentSecurityPolicyFilter (after LAST)
```

**Excluded from SAML**: `/saml/web/**`, `/favicon.ico`, `/landingPage`, `/fiduciary/**`, `/api/examServices/**`, `/jwt/api/**`, `/api/vera/**`

---

## 6. Hop-by-Hop: Keycloak → IDP Proxy (OIDC Broker)

### 6.1 Keycloak Receives SAML AuthnRequest

Keycloak's `idp` realm receives the AuthnRequest. The browser flow `browser-eks` evaluates:

1. **`auth-cookie` (ALTERNATIVE, priority 10)**: Check for existing Keycloak `KEYCLOAK_SESSION` cookie → none found
2. **`auth-spnego` (DISABLED)**: Skip
3. **`browser-eks forms` (DISABLED)**: No login form
4. **`identity-provider-redirector` (ALTERNATIVE, priority 31)**: Config `defaultProvider: vba-proxy-eks` → **auto-redirect to IDP Proxy**

No login page is ever displayed by Keycloak. Users never see the Keycloak UI.

### 6.2 Redirect to IDP Proxy

Keycloak constructs an OIDC authorization request to the `vba-proxy-eks` identity provider:

```
GET /ssoi/oauth2/authorize
    ?scope=openid
    &client_id=bip
    &redirect_uri=https://bss-{env}.dev.bip.va.gov/auth/realms/idp/broker/vba-proxy-eks/endpoint
    &response_type=code
    &state=<keycloak-state>
Host: bss-{env}.dev.bip.va.gov
```

The `state` parameter encodes the original SAML relay state so Keycloak can resume the SAML flow after OIDC completes.

### 6.3 IDP Proxy Security Filter Chains

IDP Proxy has **4 security filter chains** (ordered by priority):

| Order | Chain | Protects |
|-------|-------|----------|
| 1 | `authorizationServerSecurityFilterChain` | `/oauth2/*`, `/userinfo` |
| 2 | `legacyBipLoginSecurityFilterChain` | `/login`, `/logout` (form login) |
| 3 | `apiJwtSecurityFilterChain` | `/api/**` (Bearer JWT) |
| 4 | `uiOAuth2ClientSecurityFilterChain` | UI/static resources |

The `/oauth2/authorize` request hits chain #1. User is not authenticated → redirect to `/login`.

---

## 7. Hop-by-Hop: IDP Proxy → CSS (SOAP)

### 7.1 IAM Header Extraction

Before the login form processes, IAM headers are injected by the upstream web agent (SiteMinder or Apache).

`IAMParser.parseRequest()` checks for two header sets:

**SSOi Headers (SiteMinder/ISAM — production):**

| Header | IAMUser Field |
|--------|---------------|
| `ADSAMACCOUNTNAME` | `username` |
| `ADEMAIL` | `email` |
| `FIRSTNAME` | `firstName` |
| `LASTNAME` | `lastName` |
| `TRANSACTIONID` | `session` |

**SSOe Headers (eAuth):**

| Header | IAMUser Field |
|--------|---------------|
| `va_eauth_pid` | `vaUsername` (participant ID) |
| `va_eauth_emailaddress` | `email` |
| `va_eauth_firstname` | `firstName` |
| `va_eauth_lastname` | `lastName` |

### 7.2 Login Form Processing

`StationSelectionFormLoginProcessingFilter` creates an `IAMAuthenticationToken` → `IAMAuthenticationProvider.authenticate()`:

1. `IAMParser.parseRequest()` → extract `IAMUser` from headers
2. `validateUserLockout()` → check lockout database
3. **`UserDetailsSAL.getUserDetails()`** → SOAP call to CSS

### 7.3 CSS SOAP Call

`UserInfoEsl.java` calls `getSecurityProfileFromContext`:

**SOAP Request:**
```xml
<getSecurityProfileFromContext>
  <PersonTraits>
    <userID>JSMITH</userID>
    <stationID>283</stationID>
    <applicationID>VBMS</applicationID>
  </PersonTraits>
  <!-- Authentication context uses VBMSSYSACCT system account -->
</getSecurityProfileFromContext>
```

**Connection**: SSL-wrapped to `http://bepdev.vba.va.gov/css-webservices/CommonSecurityServiceImplWSV1`, using keystore `dev.vbms.aide.oit.va.gov.jks`.

### 7.4 CSS Response

CSS returns a `CssSecurityProfile`:

```
participantId:  "123456789"     → subjectId
secLevel:       "7"             → securityLevel
firstName:      "JOHN"          → firstName
lastName:       "SMITH"         → lastName
emailAddress:   "john@va.gov"   → email
secOfficeInd:   "y"             → secureOffice
applRole:       "Claims Asst"  → appRole
functions: [
  { name: "Manage Claim",      assignedValue: "YES" },   → MANAGE_CLAIM (authority)
  { name: "Create Note",       assignedValue: "YES" },   → CREATE_NOTE (authority)
  { name: "Route to Stn",      assignedValue: "NO"  },   → (skipped)
  ...
]
```

Function name transformation: `"App Support Analyst"` → `APP_SUPPORT_ANALYST` (spaces to underscores, uppercase).

### 7.5 CSS Result → VbaUserDetails → SecurityUser

```
CssSecurityProfile
    ↓ UserDetailsSAL.getUserDetails()
VbaUserDetails
    ↓ VbaUserDetailsToIdpSecurityUserConverter
IdpSecurityUser (extends SecurityUser)
    ↓ isMappedBEPUser = true
SecurityUserAuthentication (Spring Security principal)
```

CSS results are **cached** in `bssService_` cache to avoid repeated SOAP calls.

---

## 8. Token Cascade Back: CSS → IDP Proxy → Keycloak → VBMS Core

### 8.1 IDP Proxy → Authorization Code

After successful CSS authentication, `BipLoginSuccessHandler`:
1. Sets `BIP_LOGIN_SUCCESS` flag on session
2. Redirects back to `/oauth2/authorize` (now with authenticated user)
3. Spring Authorization Server generates **authorization code**
4. Redirects to Keycloak broker endpoint:

```
302 Location: https://bss-{env}.dev.bip.va.gov/auth/realms/idp/broker/vba-proxy-eks/endpoint
    ?code=<authorization_code>
    &state=<keycloak-state>
```

### 8.2 Keycloak → Token Exchange

Keycloak broker receives the code and performs a **server-side** token exchange:

```
POST /ssoi/oauth2/token
Host: bip-bss-idpproxy:8080
Content-Type: application/x-www-form-urlencoded

grant_type=authorization_code
&code=<authorization_code>
&redirect_uri=https://bss-{env}.dev.bip.va.gov/auth/realms/idp/broker/vba-proxy-eks/endpoint
&client_id=bip
```

IDP Proxy returns JWT tokens:

**Access Token (RSA-signed JWT):**
```json
{
  "sub": "283/JSMITH",
  "username": "JSMITH",
  "vaUsername": "JSMITH",
  "stationId": 283,
  "securityLevel": 7,
  "subjectId": "123456789",
  "authorities": ["MANAGE_CLAIM", "CREATE_NOTE"],
  "email": "john@va.gov",
  "email_verified": true,
  "given_name": "JOHN",
  "family_name": "SMITH",
  "name": "JOHN SMITH",
  "secOfficeInd": "Y",
  "appRole": "Claims Asst",
  "preferred_username": "283/JSMITH",
  "correlationIds": ["123456789^PI^200CORP^USVBA^A"],
  "aud": "bip",
  "iss": "<idpproxy-issuer-url>"
}
```

### 8.3 Keycloak → UserInfo Call

Keycloak calls the IDP Proxy's UserInfo endpoint:

```
GET /userinfo
Authorization: Bearer <access_token>
```

Returns the same claims as the access token. Keycloak uses these to populate the **broker user attributes**.

### 8.4 IDP Broker Mappers (OIDC → Keycloak User Attributes)

| OIDC Claim | Keycloak User Attribute | Mapper Type |
|------------|------------------------|-------------|
| `securityLevel` | `securityLevel` | Attribute Importer |
| `subjectId` | `subjectId` | Attribute Importer |
| `authorities` | `authorities` | Attribute Importer |
| `secOfficeInd` | `secOfficeInd` | Attribute Importer |
| `stationId` | `stationId` | Attribute Importer |
| `preferred_username` | `saml.persistent.name.id.format` | Username Template Importer |

### 8.5 SAML Attribute Mappers (Keycloak → VBMS Core)

Keycloak maps broker-imported user attributes to SAML assertion attributes (via the `vba_claims` client scope):

| Keycloak User Attribute | SAML Attribute Name | SAML Format |
|------------------------|---------------------|-------------|
| `securityLevel` | `http://vba.va.gov/css/common/securityLevel` | Basic |
| `stationId` | `http://vba.va.gov/css/common/stationId` | Basic |
| `subjectId` | `http://vba.va.gov/css/common/subjectId` | Basic |
| `authorities` | `http://vba.va.gov/css/vbms/role` | Basic |
| `firstName` | `http://vba.va.gov/css/common/fName` | Basic |
| `lastName` | `http://vba.va.gov/css/common/lName` | Basic |
| `email` | `http://vba.va.gov/css/common/email` | Basic |
| `secOfficeInd` | `http://vba.va.gov/css/common/secOfficeInd` | Basic |

### 8.6 SAML Response to VBMS Core

Keycloak constructs a SAML Response with:
- **Signed assertion** (RSA_SHA256)
- **NameID**: Persistent format, value from `saml.persistent.name.id.format` → `283/JSMITH`
- **Audience**: VBMS Core entity ID
- **Attributes**: All mapped attributes above

POSTed to VBMS Core's ACS: `https://vbms-core-dev.dev.bip.va.gov/vbmsp2/saml/SSO`

---

## 9. SAML Response Processing in VBMS Core

### 9.1 SAMLProcessingFilter

The `SAMLProcessingFilter` at `/saml/SSO` receives the POST with `SAMLResponse` parameter.

### 9.2 VbmsSAMLAuthenticationProvider

Extends Spring's `SAMLAuthenticationProvider`:
1. `super.authenticate()` → validates SAML Response signature, checks assertion conditions, decrypts if needed
2. Calls `VbmsSamlUsersDetailsService.loadUserBySAML(SAMLCredential)`
3. Tracks login metric via `BMetrics`
4. Audits via `SecurityAuditorService`

### 9.3 VbmsSamlUsersDetailsService.loadUserBySAML()

Extracts SAML attributes into `SecurityUser`:

| SAML Attribute | SecurityUser Field | Type |
|----------------|-------------------|------|
| `NameID` | `username` | String |
| `http://vba.va.gov/css/common/securityLevel` | `securityLevel` | Integer |
| `http://vba.va.gov/css/common/stationId` | `stationId` | Integer |
| `http://vba.va.gov/css/common/subjectId` | `subjectId` | String |
| `http://vba.va.gov/css/common/fName` | `firstName` | String |
| `http://vba.va.gov/css/common/lName` | `lastName` | String |
| `http://vba.va.gov/css/common/secOfficeInd` | `secureOffice` | Boolean |
| `http://vba.va.gov/css/vbms/role` | `authorities` | List\<GrantedAuthority\> |
| `http://vba.va.gov/vbms/service-operation` | `serviceOperations` | Set\<String\> |
| `http://vba.va.gov/vbms/system-operation` | `systemOperations` | Set\<String\> |

The raw SAML assertion DOM is stored on `SecurityUser` for downstream use.

### 9.4 Session Creation

On success:
- `SavedRequestAwareAuthenticationSuccessHandler` creates an HTTP session
- `SecurityUser` becomes `SecurityContextHolder.getContext().getAuthentication().getPrincipal()`
- Accessible everywhere via `SecurityUser.getCurrentUser()`
- Browser receives `JSESSIONID` cookie from WebLogic
- 302 redirect to the originally requested URL

---

## 10. XACML Authorization (PDP/PIP)

Once authenticated, every access to a veteran's record triggers XACML authorization.

### 10.1 Architecture

```
vbms-security-authz-client  → PEP (Policy Enforcement Point)
vbms-security-authz-pdp-sun → PDP (Policy Decision Point)
vbms-security-authz         → PIPs (Policy Information Points)
vbms-security-authz-api     → Attribute designator enums
```

### 10.2 Trigger: @Authorize Annotation

Service methods are annotated:

```java
@Authorize(policy = VbmsPolicy.VETERAN_PROFILE_VIEW)
public VeteranProfile getProfile(@ResourceId String fileNumber) { ... }
```

### 10.3 VbmsPep Aspect

`VbmsPep` is an `@Before` AOP aspect that intercepts `@Authorize`-annotated methods:

1. **Subject Attributes** (from `SecurityUser` → `DefaultSubjectAttributeBuilder`):

   | Attribute URN | Source |
   |---------------|--------|
   | `urn:vba.va.gov:css:common:securityLevel` | `user.getSecurityLevel()` (from SAML) |
   | `urn:vba.va.gov:css:vbms:role` | `user.getAuthorities()` |
   | `urn:vba.va.gov:css:common:stationId` | `user.getStationId()` |
   | `urn:vba.va.gov:css:common:subjectId` | `user.getSubjectId()` |
   | `urn:vba.va.gov:css:common:userName` | `user.getUsername()` |

2. **Action Attributes** (from `VbmsPolicy` enum): `action-id`, `resource-scope`, `resource-id`

3. **Resource Attributes** (from method parameters): `fileNumber`, `participantId`, `claimNumber`

### 10.4 PDP Evaluation

```
VbmsPep
  → AccessDecisionFacadeImpl.isAccessAllowed(AuthorizationRequest)
    → ContextUtil.buildRequest() → com.sun.xacml.ctx.RequestCtx
    → ContextHandlerImpl.evaluate()
      → PdpServiceImpl.evaluate()
        → SunPdpSupport.evaluate()
          → com.sun.xacml.PDP.evaluate()
```

### 10.5 PIP: Sensitivity Level Lookup

During policy evaluation, the XACML engine encounters a `ResourceAttributeDesignator` for `urn:vba.va.gov:css:common:sensitivityLevel`. This triggers the **SensitivityLevelSingleAttributeFinderModule** PIP:

```
SensitivityLevelSingleAttributeFinderModule
  → SensitivityLevelUtil.getSensitivityLevelByAttributeMap()
    → Check EhCache ("security-sensitivityLevel")
    → (cache miss) → BGS SecurityWebService.findSntvtyLevelsBySntvtyLevelsDTO()
    → Cache result
    → Return max(fileNumberLevel, claimLevel, participantLevel)
    → Default: 9 (highest sensitivity) if all lookups fail
```

**Lookup priority**: File Number → Claim Number → Participant ID. If multiple identifiers provided, returns the **maximum** sensitivity level.

### 10.6 The Core Decision

The XACML policy (`security-filtering-sensitivity-policy.xml`) evaluates:

```
user.securityLevel >= veteran.sensitivityLevel  →  PERMIT
user.securityLevel <  veteran.sensitivityLevel  →  DENY
```

| User securityLevel | Veteran sensitivityLevel | Result |
|--------------------|-------------------------|--------|
| 7 | 6 | **PERMIT** (7 ≥ 6) |
| 7 | 8 | **DENY** (7 < 8) |
| 9 | 9 | **PERMIT** (9 ≥ 9) |
| 0 | 1 | **DENY** (0 < 1) |

### 10.7 Combined Policy Rules

For veteran record access, the `deny-overrides` combining algorithm checks:

1. **Sensitivity check**: `user.securityLevel >= veteran.sensitivityLevel` — **must pass**
2. **Role check**: User must have an authorized role (24 valid roles for profile view)
3. **POA check** (VSO roles): User's organization must match veteran's POA organization
4. **Health care release** (documents): HC release indicator must be "Y"
5. **Restricted station**: Veteran's RO station restrictions
6. **Fiduciary/IRS doc**: Special document type restrictions

If sensitivity fails → **always DENY** regardless of other checks.

### 10.8 Collection Filtering

`@AuthorizeFilter` uses `SecurityFilterAspect` (`@Around`) to filter returned collections. Each item is evaluated individually through the PDP, and items that DENY are silently removed.

### 10.9 Policy Inventory

41 top-level policy sets covering: Awards, BIRLS, Claims, Correspondence, Documents, EFolder, Exams, Flashs, Manifests, Navigation, Notes, POA, Participants, Profiles, Search, Tracked Items, Veterans, Work Items, Work Queues, NWQ (National Work Queue), and system operations.

4 shared reference policies: application-shared, restricted-station, filtering-poa, **filtering-sensitivity**.

24 PIP modules: sensitivity level, POA organization, HC release, work item ownership, restricted station, deceased indicator, claim assignee, fiduciary docs, IRS docs, team profiles, and more.

---

## 11. Cookies & Sessions at Every Hop

| Component | Cookie Name | Purpose | Lifetime |
|-----------|-------------|---------|----------|
| **VBMS Core** | `JSESSIONID` | WebLogic HTTP session (contains `SecurityUser`) | Session (30 min idle) |
| **Keycloak** | `KEYCLOAK_SESSION` | SSO session across realms | 10 hours max, 30 min–1 hour idle |
| **Keycloak** | `KEYCLOAK_IDENTITY` | Identity token (JWT) | Matches session |
| **Keycloak** | `AUTH_SESSION_ID` | Auth flow tracking | Duration of auth flow |
| **IDP Proxy** | `SESSION` | Spring Session (Redis-backed in EKS) | 30 min |
| **SiteMinder** | `SMSESSION` | SiteMinder SSO token | Configured by IAM |
| **SiteMinder** | `PD-S-SESSION-ID` | ISAM session ID | Configured by IAM |
| **Apache** | `mod_auth_openidc_session` | Encrypted OIDC session (AES-SIV) | Configurable, ~1 hour |
| **Entra ID** | `ESTSAUTHPERSISTENT` | Azure AD SSO cookie | 90 days |

---

## 12. Token/Claim Mapping Chain

This traces a single attribute — **securityLevel** — through every system:

```
CSS Database
  → CssSecurityProfile.secLevel = "7"                    (SOAP response, String)
    → VbaUserDetails.securityLevel = 7                   (parsed int)
      → IdpSecurityUser.securityLevel = 7                (SecurityUser field)
        → JWT access_token claim: "securityLevel": 7     (OIDC token from IDP Proxy)
          → Keycloak user attribute: securityLevel = "7"  (IDP broker mapper)
            → SAML assertion attribute:
              Name="http://vba.va.gov/css/common/securityLevel"
              Value="7"                                   (SAML attribute mapper)
              → SecurityUser.securityLevel = 7            (VbmsSamlUsersDetailsService)
                → XACML SubjectAttributeDesignator:
                  urn:vba.va.gov:css:common:securityLevel = 7
                  → Policy: 7 >= veteran.sensitivityLevel?
```

**7 transformations** from CSS database to XACML evaluation.

---

## 13. Timeout & Expiry Reference

### IDP Proxy Token Settings
| Setting | Value |
|---------|-------|
| Access Token TTL | 30 minutes |
| Refresh Token TTL | 1 day |

### Keycloak Session Settings (EKS)

what does EKS stand for?
Elastic Kubernetes Service (Amazon EKS) — AWS's managed Kubernetes platform. In this codebase it's the deployment target for Keycloak, IDP Proxy, and the BSS infrastructure (e.g., bss-dev.dev.bip.va.gov), which is why you see suffixes like vba-proxy-eks, browser-eks, and config directories like devEKS/.

| Setting | Value |
|---------|-------|
| `accessTokenLifespan` | 20 minutes |
| `ssoSessionIdleTimeout` | 1 hour |
| `ssoSessionMaxLifespan` | 10 hours |
| `clientSessionIdleTimeout` | 1 hour |
| `clientSessionMaxLifespan` | 12 hours |
| `accessCodeLifespan` | 12 hours |

### Keycloak Session Settings (Local Docker)
| Setting | Value |
|---------|-------|
| `accessTokenLifespan` | 1 minute |
| `ssoSessionIdleTimeout` | 30 minutes |
| `ssoSessionMaxLifespan` | 10 hours |
| `accessCodeLifespan` | 1 minute |

### VBMS Core SAML Defaults
| Setting | Value |
|---------|-------|
| `maxAuthenticationAge` | 2 hours (Spring SAML default) |
| `responseSkew` | 60 seconds (Spring SAML default) |

### Sensitivity Level Cache
| Setting | Value |
|---------|-------|
| Cache Name | `security-sensitivityLevel` (EhCache) |
| TTL | Configured per environment |

---

## 14. Sequence Diagram

```
Browser          VBMS Core       Keycloak        IDP Proxy       Web Agent      CSS
  │                 │ (SP)          │ (IdP)         │ (OIDC AS)    │(SiteMinder)   │
  │  GET /vbmsp2    │               │               │              │               │
  │────────────────►│               │               │              │               │
  │                 │ No session    │               │              │               │
  │  302 AuthnReq   │               │               │              │               │
  │◄────────────────│               │               │              │               │
  │                 │               │               │              │               │
  │  SAML AuthnRequest             │               │              │               │
  │────────────────────────────────►│               │              │               │
  │                 │               │ browser-eks:  │              │               │
  │                 │               │ no cookie →   │              │               │
  │                 │               │ auto-redirect │              │               │
  │  302 /oauth2/authorize          │               │              │               │
  │◄────────────────────────────────│               │              │               │
  │                 │               │               │              │               │
  │  GET /ssoi/oauth2/authorize?client_id=bip       │              │               │
  │────────────────────────────────────────────────►│              │               │
  │                 │               │               │ No IAM hdr   │               │
  │  302 to SiteMinder login        │               │              │               │
  │◄────────────────────────────────────────────────│              │               │
  │                 │               │               │              │               │
  │  PIV/CAC login  │               │               │              │               │
  │────────────────────────────────────────────────────────────────►               │
  │                 │               │               │              │               │
  │  SM cookies + ADSAMACCOUNTNAME headers          │              │               │
  │◄───────────────────────────────────────────────────────────────│               │
  │                 │               │               │              │               │
  │  GET /ssoi/oauth2/authorize (with IAM headers)  │              │               │
  │────────────────────────────────────────────────►│              │               │
  │                 │               │               │              │               │
  │                 │               │               │  POST SOAP   │               │
  │                 │               │               │  getSecurityProfileFromContext│
  │                 │               │               │─────────────────────────────►│
  │                 │               │               │              │               │
  │                 │               │               │  CssSecurityProfile          │
  │                 │               │               │◄─────────────────────────────│
  │                 │               │               │              │               │
  │                 │               │               │ Auth code    │               │
  │  302 ?code=<code>&state=<state> │               │              │               │
  │◄────────────────────────────────────────────────│              │               │
  │                 │               │               │              │               │
  │  GET /broker/vba-proxy-eks/endpoint?code=<code> │              │               │
  │────────────────────────────────►│               │              │               │
  │                 │               │               │              │               │
  │                 │               │  POST /oauth2/token (code exchange)           │
  │                 │               │──────────────►│              │               │
  │                 │               │  JWT tokens   │              │               │
  │                 │               │◄──────────────│              │               │
  │                 │               │               │              │               │
  │                 │               │  GET /userinfo │              │               │
  │                 │               │──────────────►│              │               │
  │                 │               │  User claims  │              │               │
  │                 │               │◄──────────────│              │               │
  │                 │               │               │              │               │
  │                 │               │ Map OIDC→SAML │              │               │
  │                 │               │               │              │               │
  │                 │  POST /saml/SSO (SAML Response with attributes)              │
  │                 │◄──────────────│               │              │               │
  │                 │               │               │              │               │
  │                 │ loadUserBySAML()              │              │               │
  │                 │ → SecurityUser                │              │               │
  │                 │ → HTTP session                │              │               │
  │                 │               │               │              │               │
  │  302 + JSESSIONID               │               │              │               │
  │◄────────────────│               │               │              │               │
  │                 │               │               │              │               │
  │  GET /vbmsp2/workQueueInbox     │               │              │               │
  │────────────────►│               │               │              │               │
  │                 │               │               │              │               │
  │                 │ @Authorize → VbmsPep          │              │               │
  │                 │ → XACML PDP                   │              │               │
  │                 │   → PIP: veteran sensitivity  │              │               │
  │                 │     (BGS SOAP or cache)       │              │               │
  │                 │   → secLevel >= sensitivityLevel?             │               │
  │                 │   → PERMIT                    │              │               │
  │                 │               │               │              │               │
  │  200 HTML       │               │               │              │               │
  │◄────────────────│               │               │              │               │
```

---

## Key Takeaways

1. **VBMS Core speaks SAML to Keycloak**, not OIDC. Users never see Keycloak's login page.
2. **Keycloak is a protocol bridge**: receives SAML, brokers to OIDC, maps claims back to SAML.
3. **CSS is the single source of truth** for user identity attributes (security level, roles, station).
4. **Security level flows through 7 transformations** from CSS → XACML evaluation.
5. **XACML sensitivity check is the final gate**: `user.securityLevel >= veteran.sensitivityLevel` or DENY.
6. **Sensitivity level defaults to 9** (max) if the BGS lookup fails — fail-closed design.
7. **The Entra flow replaces SiteMinder** but the IDP Proxy → CSS → Keycloak → VBMS Core chain stays the same.
8. **System accounts** (CMP, INS, CSAP) bypass SAML but still need `SECURITYLEVEL=9` in VBMSUI.VBMSUSER to avoid XACML denials.
