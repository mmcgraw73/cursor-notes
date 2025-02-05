** NOTES PANEL **

# Quick git commands
gst     # git status
ga      # git add
gcm     # git commit -m
gp      # git push
gco     # git checkout
gd      # git diff
gl      # git pull

# NPM shortcuts and completions
ni      # npm install
nig     # npm install -g
nid     # npm install --save-dev
nr      # npm run
nls     # npm list

# Cursor & Code 
# VS Code commands
code .   # open current directory
vsc     # code .
vsca    # code --add
vscd    # code --diff
# open current directory
cursor .

# open a file
cursor path/to/file.md

# Open current directory in VS Code
code .

# Open specific file
code filename.txt

# Open with new window
code -n .

# Open and wait for file to close
code -w file.txt


# React Component Testing Boilerplate
import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, it, expect, vi } from 'vitest'

describe('Component', () => {
  it('renders correctly', () => {
    render(<Component />)
    expect(screen.getByRole('button')).toBeInTheDocument()
  })
})


#React Custom Hook Template
import { useState, useEffect } from 'react'

interface UseCustomHookProps {
  initialValue: string
}

export const useCustomHook = ({ initialValue }: UseCustomHookProps) => {
  const [value, setValue] = useState(initialValue)
  
  useEffect(() => {
    // Effect logic
  }, [])

  return { value, setValue }
}

#React API Integration Setup
import { createApi, fetchBaseQuery } from '@reduxjs/toolkit/query/react'

export const api = createApi({
  baseQuery: fetchBaseQuery({ 
    baseUrl: '/api',
    credentials: 'include',
  }),
  endpoints: (builder) => ({
    getData: builder.query({
      query: () => 'data',
    }),
  }),
})

export const { useGetDataQuery } = api




#React State Management Context and useReducer pattern
import { createContext, useContext, useReducer } from 'react';

const AppContext = createContext();

const initialState = {
  user: null,
  theme: 'light',
  settings: {}
};

function reducer(state, action) {
  switch (action.type) {
    case 'SET_USER':
      return { ...state, user: action.payload };
    case 'TOGGLE_THEME':
      return { ...state, theme: state.theme === 'light' ? 'dark' : 'light' };
    default:
      return state;
  }
}

export function AppProvider({ children }) {
  const [state, dispatch] = useReducer(reducer, initialState);

  return (
    <AppContext.Provider value={{ state, dispatch }}>
      {children}
    </AppContext.Provider>
  );
}

// Custom hook for using the context
export function useApp() {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within AppProvider');
  }
  return context;
}

// ------> Usage Example
function App() {
  return (
    <AppProvider>
      <MainLayout />
    </AppProvider>
  );
}

function SomeComponent() {
  const { state, dispatch } = useApp();
  
  const handleClick = () => {
    dispatch({ type: 'TOGGLE_THEME' });
  };

  return (
    <button onClick={handleClick}>
      Current theme: {state.theme}
    </button>
  );
}






# React State Management Compound Component Pattern
import { createContext, useState, useContext } from 'react';

const TabsContext = createContext();

export function Tabs({ children, defaultTab }) {
  const [activeTab, setActiveTab] = useState(defaultTab);

  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="tabs">{children}</div>
    </TabsContext.Provider>
  );
}

Tabs.Header = function TabHeader({ children }) {
  return <div className="tabs-header">{children}</div>;
};

Tabs.Panel = function TabPanel({ children, tabId }) {
  const { activeTab } = useContext(TabsContext);
  if (activeTab !== tabId) return null;
  return <div className="tab-panel">{children}</div>;
};

// -------> Usage Example




# React State Management with Custom Hook
import { useState, useCallback } from 'react';

export function useStore(initialState = {}) {
  const [state, setState] = useState(initialState);

  const actions = {
    updateUser: useCallback((user) => {
      setState(prev => ({ ...prev, user }));
    }, []),

    updateSettings: useCallback((settings) => {
      setState(prev => ({ ...prev, settings }));
    }, []),

    reset: useCallback(() => {
      setState(initialState);
    }, [])
  };

  return [state, actions];
}

// -------> Usage Example
function UserProfile() {
  const [state, actions] = useStore({
    user: null,
    settings: {}
  });

  const updateProfile = (data) => {
    actions.updateUser(data);
  };

  return (
    <div>
      <h1>{state.user?.name}</h1>
      <button onClick={() => updateProfile({ name: 'John' })}>
        Update
      </button>
    </div>
  );
}














*** END NOTES PANEL ***