import React, { createContext, useContext, useEffect, useState, ReactNode } from 'react';
import { database } from '../database/database';
import { ReminderService } from '../services/ReminderService';
import { NotificationService } from '../services/NotificationService';

interface AppContextType {
  isInitialized: boolean;
  error: string | null;
  initializeApp: () => Promise<void>;
}

const AppContext = createContext<AppContextType | undefined>(undefined);

export function useApp() {
  const context = useContext(AppContext);
  if (context === undefined) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
}

interface AppProviderProps {
  children: ReactNode;
}

export function AppProvider({ children }: AppProviderProps) {
  const [isInitialized, setIsInitialized] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const initializeApp = async () => {
    try {
      setError(null);
      
      // Initialize database
      await database.initialize();
      
      // Initialize notification service
      await NotificationService.initialize();
      
      // Update reminder statuses
      await ReminderService.updateReminderStatuses();
      
      setIsInitialized(true);
    } catch (err) {
      console.error('App initialization error:', err);
      setError(err instanceof Error ? err.message : 'Erro desconhecido');
    }
  };

  useEffect(() => {
    initializeApp();
  }, []);

  const value: AppContextType = {
    isInitialized,
    error,
    initializeApp,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}
