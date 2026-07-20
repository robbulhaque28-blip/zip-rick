import React, { useState, useEffect } from 'react';
import { Box, Typography, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, TextField, InputAdornment } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { Search } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function CustomersPage() {
  const [customers, setCustomers] = useState([]);
  const [search, setSearch] = useState('');
  const navigate = useNavigate();

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        let url = API + '/admin/customers?limit=100';
        if (search) url += '&search=' + encodeURIComponent(search);
        const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
        if (res.status === 401) { localStorage.removeItem('admin_token'); window.location.href = '/login'; return; }
        const data = await res.json();
        if (data.success && Array.isArray(data.data)) setCustomers(data.data);
      } catch (e) {}
    };
    load();
  }, [search]);

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 2 }}>Customer Management</Typography>
      <TextField size="small" placeholder="Search..." value={search} onChange={e => setSearch(e.target.value)}
        InputProps={{ startAdornment: <InputAdornment position="start"><Search fontSize="small" /></InputAdornment> }} sx={{ mb: 2, minWidth: 250 }} />
      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{customers.length} customer(s)</Typography>
      <TableContainer component={Paper}>
        <Table>
          <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
            <TableCell sx={{ fontWeight: 600 }}>Name</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Phone</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Rides</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Spent</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Rating</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Joined</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {customers.length === 0 && <TableRow><TableCell colSpan={6} sx={{ textAlign: 'center', py: 4, color: '#999' }}>No customers yet</TableCell></TableRow>}
            {customers.map(c => (
              <TableRow key={c.id} hover sx={{ cursor: 'pointer' }} onClick={() => navigate('/customers/' + c.id)}>
                <TableCell>{c.user ? c.user.full_name : 'N/A'}</TableCell>
                <TableCell>{c.user ? c.user.phone : 'N/A'}</TableCell>
                <TableCell>{c.total_rides || 0}</TableCell>
                <TableCell>₹{c.total_spent || 0}</TableCell>
                <TableCell>{c.rating || '0.0'}</TableCell>
                <TableCell>{c.created_at ? new Date(c.created_at).toLocaleDateString() : 'N/A'}</TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
