import React, { useState } from 'react';
import { Box, Card, CardContent, TextField, Button, Typography } from '@mui/material';
import axios from 'axios';
const API = 'http://localhost:4001/api/v1';
export default function LoginPage() {
  const [email, setEmail] = useState(''); const [password, setPassword] = useState('');
  const handleLogin = async () => {
    try {
      const res = await axios.post(API + '/auth/admin/login', { email, password });
      localStorage.setItem('admin_token', res.data.data.tokens.accessToken);
      window.location.href = '/dashboard';
    } catch (e) { alert('Login failed: ' + (e.response?.data?.error?.message || e.message)); }
  };
  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: '#F5F6FA' }}>
      <Card sx={{ maxWidth: 420, width: '100%', mx: 2 }}>
        <CardContent sx={{ p: 4 }}>
          <Box sx={{ textAlign: 'center', mb: 3 }}>
            <Typography variant="h5" sx={{ fontWeight: 700, mb: 1 }}>Zip-Rick Admin</Typography>
            <Typography variant="body2" color="text.secondary">Sign in to manage your platform</Typography>
          </Box>
          <TextField fullWidth label="Email" sx={{ mb: 2 }} value={email} onChange={e => setEmail(e.target.value)} />
          <TextField fullWidth label="Password" type="password" sx={{ mb: 3 }} value={password} onChange={e => setPassword(e.target.value)} />
          <Button fullWidth variant="contained" size="large" onClick={handleLogin}>Sign In</Button>
        </CardContent>
      </Card>
    </Box>
  );
}
