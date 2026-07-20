import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, TextField, InputAdornment } from '@mui/material';
import { useNavigate } from 'react-router-dom';
import { Search, CheckCircle, Cancel } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function DriversPage() {
  const [drivers, setDrivers] = useState([]);
  const [filter, setFilter] = useState('');
  const [search, setSearch] = useState('');
  const [msg, setMsg] = useState('');
  const navigate = useNavigate();

  const load = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      if (!token) return;
      let url = API + '/admin/drivers?limit=100';
      if (filter) url += '&status=' + filter;
      if (search) url += '&search=' + encodeURIComponent(search);
      const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
      if (res.status === 401) { localStorage.removeItem('admin_token'); window.location.href = '/login'; return; }
      const data = await res.json();
      if (data.success && Array.isArray(data.data)) setDrivers(data.data);
    } catch (e) {}
  };

  useEffect(() => { load(); }, [filter, search]);

  const approve = async (id) => {
    const token = localStorage.getItem('admin_token');
    await fetch(API + '/admin/drivers/' + id + '/approve', { method: 'POST', headers: { Authorization: 'Bearer ' + token } });
    setMsg('Driver approved!'); load();
  };

  const reject = async (id) => {
    const token = localStorage.getItem('admin_token');
    await fetch(API + '/admin/drivers/' + id + '/reject', { method: 'POST', headers: { Authorization: 'Bearer ' + token } });
    setMsg('Driver rejected!'); load();
  };

  const statusColor = (s) => s === 'approved' ? 'success' : s === 'pending' ? 'warning' : 'error';

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 2 }}>Driver Management</Typography>
      {msg && <Typography sx={{ p: 1.5, bgcolor: '#E8F5E9', borderRadius: 2, mb: 2, color: '#2E7D32' }}>{msg}</Typography>}
      
      <Box sx={{ display: 'flex', gap: 1, mb: 2, flexWrap: 'wrap', alignItems: 'center' }}>
        {['','pending','approved','rejected','suspended'].map(f => (
          <Button key={f} size="small" variant={filter === f ? 'contained' : 'outlined'} onClick={() => setFilter(f)}>
            {f || 'All'}
          </Button>
        ))}
        <Box sx={{ flexGrow: 1 }} />
        <TextField size="small" placeholder="Search name/phone..." value={search} onChange={e => setSearch(e.target.value)}
          InputProps={{ startAdornment: <InputAdornment position="start"><Search fontSize="small" /></InputAdornment> }} sx={{ minWidth: 200 }} />
      </Box>

      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{drivers.length} driver(s)</Typography>

      <TableContainer component={Paper}>
        <Table>
          <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
            <TableCell sx={{ fontWeight: 600 }}>Name</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Phone</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Online</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Docs</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Fee</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Rides</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Actions</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {drivers.length === 0 && <TableRow><TableCell colSpan={8} sx={{ textAlign: 'center', py: 4, color: '#999' }}>No drivers found</TableCell></TableRow>}
            {drivers.map(d => (
              <TableRow key={d.id} hover sx={{ cursor: 'pointer' }} onClick={() => navigate('/drivers/' + d.id)}>
                <TableCell>{d.user ? d.user.full_name : 'N/A'}</TableCell>
                <TableCell>{d.user ? d.user.phone : 'N/A'}</TableCell>
                <TableCell><Chip label={d.registration_status} color={statusColor(d.registration_status)} size="small" /></TableCell>
                <TableCell><Chip label={d.is_online ? 'Online' : 'Offline'} color={d.is_online ? 'success' : 'default'} size="small" variant="outlined" /></TableCell>
                <TableCell>{d.is_documents_uploaded ? 'Yes' : 'No'}</TableCell>
                <TableCell>{d.registration_fee_paid ? 'Paid' : 'Pending'}</TableCell>
                <TableCell>{d.total_rides || 0}</TableCell>
                <TableCell onClick={e => e.stopPropagation()}>
                  {d.registration_status === 'pending' && (
                    <><Button size="small" color="success" variant="contained" onClick={() => approve(d.id)} sx={{ mr: 0.5, minWidth: 0, p: '4px 8px' }}><CheckCircle fontSize="small" /></Button>
                      <Button size="small" color="error" variant="contained" onClick={() => reject(d.id)} sx={{ minWidth: 0, p: '4px 8px' }}><Cancel fontSize="small" /></Button></>
                  )}
                  {d.registration_status === 'approved' && <Chip label="Active" color="success" size="small" />}
                  {d.registration_status === 'rejected' && <Chip label="Rejected" color="error" size="small" />}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
