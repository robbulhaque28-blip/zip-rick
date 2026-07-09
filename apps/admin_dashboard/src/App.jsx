import React from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { ThemeProvider, createTheme, CssBaseline } from '@mui/material';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';

const theme = createTheme({
  palette: { primary: { main: '#6C63FF' }, secondary: { main: '#00D9A6' }, background: { default: '#F5F6FA' } },
  shape: { borderRadius: 12 },
});

function App() {
  return (
    <ThemeProvider theme={theme}><CssBaseline />
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="*" element={<Navigate to="/login" />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
}
export default App;
