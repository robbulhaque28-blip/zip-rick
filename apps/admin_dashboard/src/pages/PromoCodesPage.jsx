import React, { useState, useEffect } from 'react';
import { Box, Typography, Button, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Chip, TextField, Dialog, DialogTitle, DialogContent, DialogActions, IconButton } from '@mui/material';
import { Add, Delete } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function PromoCodesPage() {
  const [codes, setCodes] = useState([]);
  const [open, setOpen] = useState(false);
  const [form, setForm] = useState({ code: '', discount_type: 'percentage', discount_value: 10, expires_at: '' });
  const [msg, setMsg] = useState('');

  const load = async () => {
    try {
      const token = localStorage.getItem('admin_token');
      if (!token) return;
      const res = await fetch(API + '/admin/promo-codes', { headers: { Authorization: 'Bearer ' + token } });
      const data = await res.json();
      if (data.success && data.data?.promo_codes) setCodes(data.data.promo_codes);
    } catch (e) {}
  };

  useEffect(() => { load(); }, []);

  const create = async () => {
    const token = localStorage.getItem('admin_token');
    try {
      await fetch(API + '/admin/promo-codes', { method: 'POST', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(form) });
      setMsg('Promo code created!'); setOpen(false); load();
    } catch (e) {}
  };

  const remove = async (id) => {
    const token = localStorage.getItem('admin_token');
    await fetch(API + '/admin/promo-codes/' + id, { method: 'DELETE', headers: { Authorization: 'Bearer ' + token } });
    setMsg('Deleted!'); load();
  };

  return (
    <Box>
      <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 2 }}>
        <Typography variant="h4" sx={{ fontWeight: 700 }}>Promo Codes</Typography>
        <Button variant="contained" startIcon={<Add />} onClick={() => setOpen(true)}>New Code</Button>
      </Box>
      {msg && <Typography sx={{ p: 1.5, bgcolor: '#E8F5E9', borderRadius: 2, mb: 2, color: '#2E7D32' }}>{msg}</Typography>}

      <TableContainer component={Paper}>
        <Table>
          <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
            <TableCell sx={{ fontWeight: 600 }}>Code</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Discount</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Uses</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Max Uses</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Min Fare</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Expires</TableCell>
            <TableCell sx={{ fontWeight: 600 }}>Actions</TableCell>
          </TableRow></TableHead>
          <TableBody>
            {codes.length === 0 && <TableRow><TableCell colSpan={5} sx={{ textAlign: 'center', py: 4, color: '#999' }}>No promo codes</TableCell></TableRow>}
            {codes.map(c => (
              <TableRow key={c.id}>
                <TableCell><Chip label={c.code} color="primary" size="small" /></TableCell>
                <TableCell>{c.discount_type === 'percentage' ? (c.discount || 0) + '%' : '₹' + (c.discount || 0)}</TableCell>
                <TableCell><Chip label={c.status || 'active'} size="small" color={c.status === 'active' ? 'success' : 'default'} /></TableCell>
                <TableCell>{c.expiry_date ? new Date(c.expiry_date).toLocaleDateString() : 'Never'}</TableCell>
                <TableCell><IconButton size="small" color="error" onClick={() => remove(c.id)}><Delete /></IconButton></TableCell>
              </TableRow>
            ))}
          </TableBody>
        </Table>
      </TableContainer>

      <Dialog open={open} onClose={() => setOpen(false)} maxWidth="sm" fullWidth>
        <DialogTitle>Create Promo Code</DialogTitle>
        <DialogContent>
          <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2, mt: 1 }}>
            <TextField label="Code" value={form.code} onChange={e => setForm({...form, code: e.target.value.toUpperCase()})} />
            <TextField label="Discount Value" type="number" value={form.discount_value} onChange={e => setForm({...form, discount_value: parseFloat(e.target.value) || 0})} />
            <TextField label="Expires At" type="date" value={form.expires_at} onChange={e => setForm({...form, expires_at: e.target.value})} InputLabelProps={{ shrink: true }} />
          </Box>
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setOpen(false)}>Cancel</Button>
          <Button variant="contained" onClick={create}>Create</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
