import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, MenuItem, Select, TextField } from '@mui/material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function RidesPage() {
  const [rides, setRides] = useState([]);
  const [tab, setTab] = useState('all');
  const [statusFilter, setStatusFilter] = useState('');

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        let url = tab === 'active' ? API + '/admin/rides/active' : API + '/admin/rides?limit=100';
        if (statusFilter && tab === 'all') url += '&status=' + statusFilter;
        const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
        if (res.status === 401) { localStorage.removeItem('admin_token'); window.location.href = '/login'; return; }
        const data = await res.json();
        if (data.success) {
          if (tab === 'active' && data.data?.rides) setRides(data.data.rides);
          else if (Array.isArray(data.data)) setRides(data.data);
        }
      } catch (e) {}
    };
    load();
  }, [tab, statusFilter]);

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 2 }}>Ride Management</Typography>
      <Box sx={{ display: 'flex', gap: 1, mb: 2, alignItems: 'center' }}>
        <Button size="small" variant={tab === 'all' ? 'contained' : 'outlined'} onClick={() => setTab('all')}>All Rides</Button>
        <Button size="small" variant={tab === 'active' ? 'contained' : 'outlined'} onClick={() => setTab('active')}>Active Rides</Button>
        {tab === 'all' && (
          <Select size="small" value={statusFilter} onChange={e => setStatusFilter(e.target.value)} displayEmpty sx={{ minWidth: 130, ml: 2 }}>
            <MenuItem value="">All Status</MenuItem>
            <MenuItem value="pending">Pending</MenuItem>
            <MenuItem value="searching">Searching</MenuItem>
            <MenuItem value="driver_assigned">Assigned</MenuItem>
            <MenuItem value="started">Started</MenuItem>
            <MenuItem value="completed">Completed</MenuItem>
            <MenuItem value="cancelled">Cancelled</MenuItem>
          </Select>
        )}
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{rides.length} ride(s)</Typography>
      <TableContainer component={Paper}>
        <Table>
          <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
            <TableCell sx={{ fontWeight: 600 }}>Ride #</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Customer</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Driver</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Pickup</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Drop</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Fare</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {rides.length === 0 && <TableRow><TableCell colSpan={7} sx={{ textAlign: 'center', py: 4, color: '#999' }}>No rides found</TableCell></TableRow>}
            {rides.map(r => (
              <TableRow key={r.id}>
                <TableCell>{r.ride_number || 'N/A'}</TableCell>
                <TableCell>{r.customer?.user?.full_name || 'N/A'}</TableCell>
                <TableCell>{r.driver?.user?.full_name || 'Not assigned'}</TableCell>
                <TableCell sx={{ maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.pickup_address || ''}</TableCell>
                <TableCell sx={{ maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.drop_address || ''}</TableCell>
                <TableCell>₹{r.total_fare || 0}</TableCell>
                <TableCell><Chip label={r.status} size="small" color={r.status === 'completed' ? 'success' : r.status === 'cancelled' ? 'error' : r.status === 'started' ? 'info' : 'warning'} /></TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
