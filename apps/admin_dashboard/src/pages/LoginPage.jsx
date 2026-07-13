import React, { useState } from 'react';
import { Box, Card, CardContent, TextField, Button, Typography } from '@mui/material';
import axios from 'axios';

const API = 'http://localhost:3000/api/v1';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleLogin = async () => {
    setLoading(true);
    setError('');
    try {
      const res = await axios.post(API + '/auth/admin/login', { email, password });
      if (res.data.success && res.data.data && res.data.data.tokens) {
        localStorage.setItem('admin_token', res.data.data.tokens.accessToken);
        window.location.href = '/dashboard';
      } else {
        setError('Invalid response from server');
      }
    } catch (e) {
      setError(e.response?.data?.error?.message || 'Login failed. Is the backend running?');
    }
    setLoading(false);
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center', bgcolor: '#F5F6FA' }}>
      <Card sx={{ maxWidth: 420, width: '100%', mx: 2 }}>
        <CardContent sx={{ p: 4 }}>
          <Box sx={{ textAlign: 'center', mb: 3 }}>
            <Typography variant="h5" sx={{ fontWeight: 700, mb: 1 }}>Zip-Rick Admin</Typography>
            <Typography variant="body2" color="text.secondary">Sign in to manage your platform</Typography>
          </Box>
          {error && <Typography color="error" sx={{ mb: 2, textAlign: 'center' }}>{error}</Typography>}
          <TextField fullWidth label="Email" sx={{ mb: 2 }} value={email} onChange={e => setEmail(e.target.value)} />
          <TextField fullWidth label="Password" type="password" sx={{ mb: 3 }} value={password} onChange={e => setPassword(e.target.value)} />
          <Button fullWidth variant="contained" size="large" onClick={handleLogin} disabled={loading}>
            {loading ? 'Signing in...' : 'Sign In'}
          </Button>
        </CardContent>
      </Card>
    </Box>
  );
}