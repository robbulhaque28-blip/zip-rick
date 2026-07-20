import React, { useState, useEffect } from 'react';
import { Box, Typography, Card, CardContent, TextField, Button, Grid, Switch, FormControlLabel } from '@mui/material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function SettingsPage() {
  const token = localStorage.getItem('admin_token');
  const [msg, setMsg] = useState('');
  const [fare, setFare] = useState({ base_fare: 30, per_km: 12, per_minute: 1, minimum_fare: 30 });
  const [fee, setFee] = useState({ promotional: 499, standard: 999, promotion_active: true });
  const [commission, setCommission] = useState({ rate: 10 });

  useEffect(() => {
    const load = async () => {
      try {
        const [f, reg, c] = await Promise.all([
          fetch(API + '/admin/settings/fare', { headers: { Authorization: 'Bearer ' + token } }).then(r => r.json()),
          fetch(API + '/admin/settings/registration-fee', { headers: { Authorization: 'Bearer ' + token } }).then(r => r.json()),
          fetch(API + '/admin/settings/commission', { headers: { Authorization: 'Bearer ' + token } }).then(r => r.json()),
        ]);
        if (f.success && f.data?.fare_rates) setFare(f.data.fare_rates);
        if (reg.success && reg.data?.registration_fee) setFee(reg.data.registration_fee);
        if (c.success && c.data?.commission) setCommission(c.data.commission);
      } catch (e) {}
    };
    load();
  }, []);

  const saveFare = async () => {
    await fetch(API + '/admin/settings/fare', { method: 'PUT', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(fare) });
    setMsg('Fare settings saved!');
  };
  const saveFee = async () => {
    await fetch(API + '/admin/settings/registration-fee', { method: 'PUT', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(fee) });
    setMsg('Registration fee updated!');
  };
  const saveCommission = async () => {
    await fetch(API + '/admin/settings/commission', { method: 'PUT', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(commission) });
    setMsg('Commission updated!');
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>System Settings</Typography>
      {msg && <Typography sx={{ p: 1.5, bgcolor: '#E8F5E9', borderRadius: 2, mb: 2, color: '#2E7D32' }}>{msg}</Typography>}
      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card><CardContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>Fare Rates</Typography>
            <TextField label="Base Fare (₹)" type="number" value={fare.base_fare} onChange={e => setFare({...fare, base_fare: e.target.value})} />
            <TextField label="Per KM (₹)" type="number" value={fare.per_km} onChange={e => setFare({...fare, per_km: e.target.value})} />
            <TextField label="Per Minute (₹)" type="number" value={fare.per_minute} onChange={e => setFare({...fare, per_minute: e.target.value})} />
            <TextField label="Min Fare (₹)" type="number" value={fare.minimum_fare} onChange={e => setFare({...fare, minimum_fare: e.target.value})} />
            <Button variant="contained" onClick={saveFare} sx={{ alignSelf: 'flex-start' }}>Save Fare</Button>
          </CardContent></Card>
        </Grid>
        <Grid item xs={12} md={6}>
          <Card><CardContent sx={{ display: 'flex', flexDirection: 'column', gap: 2, p: 3 }}>
            <Typography variant="h6" sx={{ fontWeight: 600 }}>Registration Fee</Typography>
            <TextField label="Standard (₹)" type="number" value={fee.standard} onChange={e => setFee({...fee, standard: parseFloat(e.target.value) || 999})} />
            <TextField label="Promotional (₹)" type="number" value={fee.promotional} onChange={e => setFee({...fee, promotional: parseFloat(e.target.value) || 499})} />
            <FormControlLabel control={<Switch checked={fee.promotion_active} onChange={e => setFee({...fee, promotion_active: e.target.checked})} />} label="Promotion Active" />
            <Button variant="contained" onClick={saveFee} sx={{ alignSelf: 'flex-start' }}>Save Fee</Button>
            <Box sx={{ mt: 2, pt: 2, borderTop: '1px solid #eee' }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Commission</Typography>
              <TextField label="Rate (%)" type="number" value={commission.rate} onChange={e => setCommission({...commission, rate: parseFloat(e.target.value) || 10})} />
              <Button variant="contained" onClick={saveCommission} sx={{ alignSelf: 'flex-start', mt: 2 }}>Save Commission</Button>
            </Box>
          </CardContent></Card>
        </Grid>
      </Grid>
    </Box>
  );
}
