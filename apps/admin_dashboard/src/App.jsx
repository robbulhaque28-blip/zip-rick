import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, Link, useLocation } from 'react-router-dom';
import { ThemeProvider, createTheme, CssBaseline, AppBar, Toolbar, Typography, Drawer, List, ListItem, ListItemIcon, ListItemText, Box, Button } from '@mui/material';
import { Dashboard, PeopleAlt, DirectionsCar, Settings } from '@mui/icons-material';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import DriversPage from './pages/DriversPage';
import CustomersPage from './pages/CustomersPage';
import RidesPage from './pages/RidesPage';
import SettingsPage from './pages/SettingsPage';

const theme = createTheme({
  palette: { primary: { main: '#6C63FF' }, secondary: { main: '#00D9A6' }, background: { default: '#F5F6FA' } },
  shape: { borderRadius: 12 },
});

const drawerWidth = 240;

function Layout() {
  const location = useLocation();
  const token = localStorage.getItem('admin_token');
  if (!token) return <Navigate to="/login" />;

  const menu = [
    { text: 'Dashboard', icon: <Dashboard />, path: '/dashboard' },
    { text: 'Drivers', icon: <PeopleAlt />, path: '/drivers' },
    { text: 'Customers', icon: <PeopleAlt />, path: '/customers' },
    { text: 'Rides', icon: <DirectionsCar />, path: '/rides' },
    { text: 'Settings', icon: <Settings />, path: '/settings' },
  ];

  return (
    <Box sx={{ display: 'flex' }}>
      <AppBar position="fixed" sx={{ zIndex: 1201, backgroundColor: '#1A1D26' }}>
        <Toolbar>
          <Typography variant="h6" noWrap sx={{ flexGrow: 1 }}>Zip-Rick Admin</Typography>
          <Button color="inherit" onClick={() => { localStorage.removeItem('admin_token'); window.location.href = '/login'; }}>Logout</Button>
        </Toolbar>
      </AppBar>
      <Drawer variant="permanent" sx={{ width: drawerWidth, flexShrink: 0, '& .MuiDrawer-paper': { width: drawerWidth, boxSizing: 'border-box', backgroundColor: '#1A1D26', color: 'white' } }}>
        <Toolbar />
        <List>
          {menu.map((item) => (
            <ListItem button key={item.text} component={Link} to={item.path} selected={location.pathname === item.path} sx={{ '&.Mui-selected': { backgroundColor: '#6C63FF44' } }}>
              <ListItemIcon sx={{ color: 'white' }}>{item.icon}</ListItemIcon>
              <ListItemText primary={item.text} />
            </ListItem>
          ))}
        </List>
      </Drawer>
      <Box component="main" sx={{ flexGrow: 1, p: 3, mt: 8 }}>
        <Routes>
          <Route path="/dashboard" element={<DashboardPage />} />
          <Route path="/drivers" element={<DriversPage />} />
          <Route path="/customers" element={<CustomersPage />} />
          <Route path="/rides" element={<RidesPage />} />
          <Route path="/settings" element={<SettingsPage />} />
          <Route path="*" element={<Navigate to="/dashboard" />} />
        </Routes>
      </Box>
    </Box>
  );
}

function App() {
  return (
    <ThemeProvider theme={theme}><CssBaseline />
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/*" element={<Layout />} />
        </Routes>
      </BrowserRouter>
    </ThemeProvider>
  );
}
export default App;