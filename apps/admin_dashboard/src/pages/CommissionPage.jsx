import React, { useState, useEffect } from 'react';
import {
  Box, Typography, Button, Table, TableBody, TableCell, TableContainer,
  TableHead, TableRow, Paper, Chip, Tabs, Tab, Dialog, DialogTitle,
  DialogContent, DialogActions, TextField, Alert, Card, CardContent, Grid,
} from '@mui/material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function CommissionPage() {
  const [tab, setTab] = useState(0);
  const [payments, setPayments] = useState([]);
  const [outstanding, setOutstanding] = useState([]);
  const [totalOutstanding, setTotalOutstanding] = useState(0);
  const [msg, setMsg] = useState('');
  const [err, setErr] = useState('');
  const [rejectFor, setRejectFor] = useState(null);
  const [rejectReason, setRejectReason] = useState('');
  const [settings, setSettings] = useState({
    rate: 10, block_threshold: 20, upi_id: '',
    bank_account_name: '', bank_account_number: '', bank_ifsc: '',
  });

  const token = () => localStorage.getItem('admin_token');

  const load = async () => {
    setErr('');
    try {
      const h = { Authorization: 'Bearer ' + token() };
      const [p, o, s] = await Promise.all([
        fetch(API + '/admin/commission/payments', { headers: h }).then(r => r.json()),
        fetch(API + '/admin/commission/outstanding', { headers: h }).then(r => r.json()),
        fetch(API + '/admin/settings/commission', { headers: h }).then(r => r.json()),
      ]);
      if (p.success) setPayments(p.data?.payments || []);
      if (o.success) {
        setOutstanding(o.data?.drivers || []);
        setTotalOutstanding(o.data?.total_outstanding || 0);
      }
      if (s.success && s.data?.commission) {
        setSettings(prev => ({ ...prev, ...s.data.commission }));
      }
    } catch (e) {
      setErr('Could not load commission data');
    }
  };

  useEffect(() => { load(); }, []);

  const confirm = async (id) => {
    try {
      const res = await fetch(API + '/admin/commission/payments/' + id + '/confirm', {
        method: 'POST', headers: { Authorization: 'Bearer ' + token() },
      });
      const d = await res.json();
      if (d.success) { setMsg('Payment confirmed. Driver dues cleared.'); load(); }
      else setErr(d.error?.message || 'Could not confirm');
    } catch (e) { setErr('Could not confirm'); }
  };

  const doReject = async () => {
    try {
      const res = await fetch(API + '/admin/commission/payments/' + rejectFor + '/reject', {
        method: 'POST',
        headers: { Authorization: 'Bearer ' + token(), 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason: rejectReason || 'Payment not received' }),
      });
      const d = await res.json();
      if (d.success) { setMsg('Payment rejected'); setRejectFor(null); setRejectReason(''); load(); }
      else setErr(d.error?.message || 'Could not reject');
    } catch (e) { setErr('Could not reject'); }
  };

  const saveSettings = async () => {
    try {
      const res = await fetch(API + '/admin/settings/commission', {
        method: 'PUT',
        headers: { Authorization: 'Bearer ' + token(), 'Content-Type': 'application/json' },
        body: JSON.stringify(settings),
      });
      const d = await res.json();
      if (d.success) setMsg('Settings saved');
      else setErr('Could not save settings');
    } catch (e) { setErr('Could not save settings'); }
  };

  const statusChip = (s) => {
    if (s === 'confirmed') return <Chip label="Confirmed" color="success" size="small" />;
    if (s === 'rejected') return <Chip label="Rejected" color="error" size="small" />;
    return <Chip label="Pending" color="warning" size="small" />;
  };

  const pendingCount = payments.filter(p => p.status === 'pending').length;

  return (
    <Box>
      <Typography variant="h4" sx={{ mb: 2 }}>Commission</Typography>
      {msg && <Alert severity="success" sx={{ mb: 2 }} onClose={() => setMsg('')}>{msg}</Alert>}
      {err && <Alert severity="error" sx={{ mb: 2 }} onClose={() => setErr('')}>{err}</Alert>}

      <Grid container spacing={2} sx={{ mb: 3 }}>
        <Grid item xs={12} sm={4}>
          <Card><CardContent>
            <Typography color="text.secondary" variant="body2">Total outstanding</Typography>
            <Typography variant="h5">Rs {Number(totalOutstanding).toFixed(0)}</Typography>
          </CardContent></Card>
        </Grid>
        <Grid item xs={12} sm={4}>
          <Card><CardContent>
            <Typography color="text.secondary" variant="body2">Awaiting confirmation</Typography>
            <Typography variant="h5">{pendingCount}</Typography>
          </CardContent></Card>
        </Grid>
        <Grid item xs={12} sm={4}>
          <Card><CardContent>
            <Typography color="text.secondary" variant="body2">Drivers owing</Typography>
            <Typography variant="h5">{outstanding.length}</Typography>
          </CardContent></Card>
        </Grid>
      </Grid>

      <Tabs value={tab} onChange={(e, v) => setTab(v)} sx={{ mb: 2 }}>
        <Tab label={'Payments' + (pendingCount ? ' (' + pendingCount + ')' : '')} />
        <Tab label="Who owes" />
        <Tab label="Settings" />
      </Tabs>

      {tab === 0 && (
        <TableContainer component={Paper}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Driver</TableCell>
                <TableCell>Amount</TableCell>
                <TableCell>Method</TableCell>
                <TableCell>Reference</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Action</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {payments.length === 0 && (
                <TableRow><TableCell colSpan={6}>No commission payments yet.</TableCell></TableRow>
              )}
              {payments.map(p => (
                <TableRow key={p.id}>
                  <TableCell>
                    {p.driver?.user?.full_name || '-'}<br />
                    <Typography variant="caption" color="text.secondary">
                      {p.driver?.user?.phone || ''}
                    </Typography>
                  </TableCell>
                  <TableCell>Rs {Number(p.amount).toFixed(0)}</TableCell>
                  <TableCell>{p.method}</TableCell>
                  <TableCell>{p.reference || '-'}</TableCell>
                  <TableCell>{statusChip(p.status)}</TableCell>
                  <TableCell>
                    {p.status === 'pending' ? (
                      <>
                        <Button size="small" variant="contained" color="success"
                          onClick={() => confirm(p.id)} sx={{ mr: 1 }}>
                          Confirm
                        </Button>
                        <Button size="small" variant="outlined" color="error"
                          onClick={() => setRejectFor(p.id)}>
                          Reject
                        </Button>
                      </>
                    ) : (
                      <Typography variant="caption" color="text.secondary">
                        {p.rejection_reason || '-'}
                      </Typography>
                    )}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {tab === 1 && (
        <TableContainer component={Paper}>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Driver</TableCell>
                <TableCell>Phone</TableCell>
                <TableCell>Owes</TableCell>
                <TableCell>Earned</TableCell>
                <TableCell>Paid so far</TableCell>
                <TableCell>Online</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {outstanding.length === 0 && (
                <TableRow><TableCell colSpan={6}>Nobody owes commission right now.</TableCell></TableRow>
              )}
              {outstanding.map(d => (
                <TableRow key={d.driver_id}>
                  <TableCell>{d.name || '-'}</TableCell>
                  <TableCell>{d.phone || '-'}</TableCell>
                  <TableCell><b>Rs {Number(d.commission_due).toFixed(0)}</b></TableCell>
                  <TableCell>Rs {Number(d.total_earnings).toFixed(0)}</TableCell>
                  <TableCell>Rs {Number(d.total_commission_paid).toFixed(0)}</TableCell>
                  <TableCell>
                    {d.is_online
                      ? <Chip label="Online" color="success" size="small" />
                      : <Chip label="Offline" size="small" />}
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      {tab === 2 && (
        <Paper sx={{ p: 3, maxWidth: 520 }}>
          <Typography variant="h6" sx={{ mb: 2 }}>Commission settings</Typography>
          <TextField fullWidth label="Commission rate (%)" type="number" sx={{ mb: 2 }}
            value={settings.rate}
            onChange={e => setSettings({ ...settings, rate: Number(e.target.value) })} />
          <TextField fullWidth label="Block driver when dues reach (Rs)" type="number" sx={{ mb: 1 }}
            value={settings.block_threshold}
            onChange={e => setSettings({ ...settings, block_threshold: Number(e.target.value) })} />
          <Typography variant="caption" color="text.secondary">
            At {settings.rate}% commission, Rs {settings.block_threshold} is reached after about
            Rs {Math.round((Number(settings.block_threshold) || 0) * 100 / (Number(settings.rate) || 10))} of fares.
          </Typography>

          <Typography variant="subtitle2" sx={{ mt: 3, mb: 1 }}>Where drivers should pay</Typography>
          <TextField fullWidth label="UPI ID" sx={{ mb: 2 }}
            value={settings.upi_id || ''}
            onChange={e => setSettings({ ...settings, upi_id: e.target.value })} />
          <TextField fullWidth label="Bank account name" sx={{ mb: 2 }}
            value={settings.bank_account_name || ''}
            onChange={e => setSettings({ ...settings, bank_account_name: e.target.value })} />
          <TextField fullWidth label="Bank account number" sx={{ mb: 2 }}
            value={settings.bank_account_number || ''}
            onChange={e => setSettings({ ...settings, bank_account_number: e.target.value })} />
          <TextField fullWidth label="IFSC code" sx={{ mb: 2 }}
            value={settings.bank_ifsc || ''}
            onChange={e => setSettings({ ...settings, bank_ifsc: e.target.value })} />
          <Button variant="contained" onClick={saveSettings}>Save settings</Button>
        </Paper>
      )}

      <Dialog open={!!rejectFor} onClose={() => setRejectFor(null)}>
        <DialogTitle>Reject payment</DialogTitle>
        <DialogContent>
          <Typography variant="body2" sx={{ mb: 2 }}>
            The driver's dues will stay unchanged.
          </Typography>
          <TextField autoFocus fullWidth label="Reason" value={rejectReason}
            onChange={e => setRejectReason(e.target.value)} />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setRejectFor(null)}>Cancel</Button>
          <Button color="error" variant="contained" onClick={doReject}>Reject</Button>
        </DialogActions>
      </Dialog>
    </Box>
  );
}
