import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme, CssBaseline } from '@mui/material';
import { QueryClient, QueryClientProvider } from 'react-query';
import { Toaster } from 'react-hot-toast';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';

const theme = createTheme({
  palette: { primary: { main: '#6C63FF' }, secondary: { main: '#00D9A6' }, background: { default: '#F5F6FA' } },
  shape: { borderRadius: 12 },
  typography: { fontFamily: '"Inter", sans-serif', h4: { fontWeight: 700 }, button: { textTransform: 'none', fontWeight: 600 } },
});
const queryClient = new QueryClient({ defaultOptions: { queries: { retry: 2, refetchOnWindowFocus: false, staleTime: 30000 } } });

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider theme={theme}><CssBaseline />
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<LoginPage />} />
            <Route path="/dashboard" element={<DashboardPage />} />
            <Route path="*" element={<Navigate to="/dashboard" />} />
          </Routes>
        </BrowserRouter>
        <Toaster position="top-right" />
      </ThemeProvider>
    </QueryClientProvider>
  );
}
export default App;
