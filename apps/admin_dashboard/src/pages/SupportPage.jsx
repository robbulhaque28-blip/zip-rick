import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, Badge } from '@mui/material';
import { Warning } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function SupportPage() {
  const [tickets, setTickets] = useState([]);
  const [filter, setFilter] = useState('');

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        let url = API + '/admin/support-tickets';
        if (filter) url += '?status=' + filter;
        const res = await fetch(url, { headers: { Authorization: 'Bearer ' + token } });
        if (res.status === 401) { localStorage.removeItem('admin_token'); window.location.href = '/login'; return; }
        const data = await res.json();
        if (data.success && data.data && data.data.tickets) setTickets(data.data.tickets);
      } catch (e) {}
    };
    load();
    const t = setInterval(load, 15000);
    return () => clearInterval(t);
  }, [filter]);

  const updateStatus = async (id, status) => {
    try {
      const token = localStorage.getItem('admin_token');
      await fetch(API + '/admin/support-tickets/' + id, {
        method: 'PUT',
        headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
        body: JSON.stringify({ status }),
      });
      setTickets(tickets.map(t => t.id === id ? { ...t, status } : t));
    } catch (e) {}
  };

  const sosCount = tickets.filter(t => t.priority === 'urgent' && t.status === 'open').length;

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 2 }}>
        Support Tickets
        {sosCount > 0 && <Chip label={`${sosCount} SOS`} color="error" size="small" icon={<Warning />} sx={{ ml: 2 }} />}
      </Typography>
      <Box sx={{ display: 'flex', gap: 1, mb: 2 }}>
        {['','open','resolved','closed'].map(f => (
          <Button key={f} size="small" variant={filter === f ? 'contained' : 'outlined'} onClick={() => setFilter(f)}
            color={f === '' && sosCount > 0 ? 'error' : 'primary'}>
            {f || 'All'}
          </Button>
        ))}
      </Box>
      <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>{tickets.length} ticket(s)</Typography>
      <TableContainer component={Paper}>
        <Table>
          <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
            <TableCell sx={{ fontWeight: 600 }}>User</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Subject</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Priority</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Date</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Actions</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {tickets.length === 0 && <TableRow><TableCell colSpan={6} sx={{ textAlign: 'center', py: 4, color: '#999' }}>No tickets</TableCell></TableRow>}
            {tickets.map(t => (
              <TableRow key={t.id} sx={{ bgcolor: t.priority === 'urgent' ? '#FFF0F0' : 'inherit' }}>
                <TableCell>
                  {t.priority === 'urgent' && <Badge color="error" variant="dot" sx={{ mr: 1 }} />}
                  {t.user?.full_name || 'N/A'}<br /><Typography variant="caption" color="text.secondary">{t.user?.phone || ''}</Typography>
                </TableCell>
                <TableCell sx={{ fontWeight: t.priority === 'urgent' ? 600 : 400 }}>{t.subject}</TableCell>
                <TableCell><Chip label={t.status} size="small" color={t.status === 'open' ? 'warning' : t.status === 'resolved' ? 'success' : 'default'} /></TableCell>
                <TableCell><Chip label={t.priority} size="small" color={t.priority === 'urgent' ? 'error' : t.priority === 'high' ? 'warning' : 'info'} /></TableCell>
                <TableCell>{t.created_at ? new Date(t.created_at).toLocaleString() : ''}</TableCell>
                <TableCell>
                  {t.status === 'open' && (
                    <Button size="small" color="success" variant="contained" onClick={() => updateStatus(t.id, 'resolved')} sx={{ mr: 0.5 }}>
                      Resolve
                    </Button>
                  )}
                  {t.status === 'resolved' && <Button size="small" onClick={() => updateStatus(t.id, 'open')}>Reopen</Button>}
                </TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>
    </Box>
  );
}
