import React, { useState, useEffect } from 'react';
import { Box, Typography, Card, CardContent, TextField, Button, Grid, Switch, FormControlLabel, Divider } from '@mui/material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

function Field({ label, value, onChange, ...props }) {
  return (
    <TextField
      fullWidth
      size="small"
      variant="outlined"
      label={label}
      type="number"
      value={value}
      onChange={onChange}
      InputLabelProps={{ shrink: true, style: { fontSize: 14, fontWeight: 600, color: '#555' } }}
      inputProps={{ style: { fontSize: 16, fontWeight: 500, padding: '10px 12px' } }}
      sx={{ '& .MuiOutlinedInput-root': { borderRadius: '8px' } }}
      {...props}
    />
  );
}

export default function SettingsPage() {
  const token = localStorage.getItem('admin_token');
  const [msg, setMsg] = useState('');
  const [fare, setFare] = useState({
    single_base_fare: 30, single_per_km: 12, single_per_minute: 1,
    sharing_base_fare: 20, sharing_per_km: 8, sharing_per_minute: 0.5,
    minimum_fare: 30, night_charge_multiplier: 1.5,
    peak_multiplier: 1.2, cancellation_fee_customer: 10
  });
  const [fee, setFee] = useState({ promotional: 499, standard: 999, promotion_active: true });
  const [commission, setCommission] = useState({ rate: 10 });

  useEffect(() => {
    const loadData = async () => {
      try {
        const [fRes, regRes, cRes] = await Promise.all([
          fetch(API + '/admin/settings/fare', { headers: { Authorization: 'Bearer ' + token } }),
          fetch(API + '/admin/settings/registration-fee', { headers: { Authorization: 'Bearer ' + token } }),
          fetch(API + '/admin/settings/commission', { headers: { Authorization: 'Bearer ' + token } }),
        ]);
        const [fData, regData, cData] = await Promise.all([fRes.json(), regRes.json(), cRes.json()]);
        if (fData.success && fData.data?.fare_rates) setFare(prev => ({ ...prev, ...fData.data.fare_rates }));
        if (regData.success && regData.data?.registration_fee) setFee(regData.data.registration_fee);
        if (cData.success && cData.data?.commission) setCommission(cData.data.commission);
      } catch (e) { console.log('Load error:', e); }
    };
    loadData();
  }, []);

  const saveFare = async () => {
    try { await fetch(API + '/admin/settings/fare', { method: 'PUT', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(fare) }); setMsg('Fare rates saved!'); }
    catch (e) { setMsg('Failed to save'); }
  };
  const saveFee = async () => {
    try { await fetch(API + '/admin/settings/registration-fee', { method: 'PUT', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(fee) }); setMsg('Registration fee saved!'); }
    catch (e) { setMsg('Failed to save'); }
  };
  const saveCommission = async () => {
    try { await fetch(API + '/admin/settings/commission', { method: 'PUT', headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' }, body: JSON.stringify(commission) }); setMsg('Commission saved!'); }
    catch (e) { setMsg('Failed to save'); }
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>System Settings</Typography>
      {msg && <Typography sx={{ p: 1.5, bgcolor: '#E8F5E9', borderRadius: 2, mb: 2, color: '#2E7D32' }}>{msg}</Typography>}

      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2.5, color: '#6C63FF' }}>🚗 Single Ride Fare</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <Field label="Base Fare (₹)" value={fare.single_base_fare} onChange={e => setFare({...fare, single_base_fare: parseFloat(e.target.value) || 30})} />
                <Field label="Per KM (₹)" value={fare.single_per_km} onChange={e => setFare({...fare, single_per_km: parseFloat(e.target.value) || 12})} />
                <Field label="Per Minute (₹)" value={fare.single_per_minute} onChange={e => setFare({...fare, single_per_minute: parseFloat(e.target.value) || 1})} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2.5, color: '#00D9A6' }}>👥 Sharing Ride Fare</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <Field label="Base Fare (₹)" value={fare.sharing_base_fare} onChange={e => setFare({...fare, sharing_base_fare: parseFloat(e.target.value) || 20})} />
                <Field label="Per KM (₹)" value={fare.sharing_per_km} onChange={e => setFare({...fare, sharing_per_km: parseFloat(e.target.value) || 8})} />
                <Field label="Per Minute (₹)" value={fare.sharing_per_minute} onChange={e => setFare({...fare, sharing_per_minute: parseFloat(e.target.value) || 0.5})} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2.5 }}>⚙️ Common Fare Settings</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <Field label="Minimum Fare (₹)" value={fare.minimum_fare} onChange={e => setFare({...fare, minimum_fare: parseFloat(e.target.value) || 30})} />
                <Field label="Night Multiplier" value={fare.night_charge_multiplier} onChange={e => setFare({...fare, night_charge_multiplier: parseFloat(e.target.value) || 1.5})} inputProps={{ step: 0.1 }} />
                <Field label="Peak Multiplier" value={fare.peak_multiplier} onChange={e => setFare({...fare, peak_multiplier: parseFloat(e.target.value) || 1.2})} inputProps={{ step: 0.1 }} />
                <Field label="Cancellation Fee (₹)" value={fare.cancellation_fee_customer} onChange={e => setFare({...fare, cancellation_fee_customer: parseFloat(e.target.value) || 10})} />
                <Button variant="contained" onClick={saveFare} sx={{ alignSelf: 'flex-start', mt: 1 }}>Save All Fare Rates</Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2.5, pb: 1, borderBottom: '2px solid #6C63FF' }}>📋 Registration Fee</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <div style={{ marginTop: 8 }}>
                  <Field label="Standard Fee (₹)" value={fee.standard} onChange={e => setFee({...fee, standard: parseFloat(e.target.value) || 999})} />
                </div>
                <Field label="Promotional Fee (₹)" value={fee.promotional} onChange={e => setFee({...fee, promotional: parseFloat(e.target.value) || 499})} />
                <FormControlLabel control={<Switch checked={fee.promotion_active} onChange={e => setFee({...fee, promotion_active: e.target.checked})} />} label="Promotion Active" />
                <Button variant="contained" onClick={saveFee} sx={{ alignSelf: 'flex-start', mt: 1 }}>Save Fee</Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2.5, pb: 1, borderBottom: '2px solid #00D9A6' }}>💰 Commission</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <div style={{ marginTop: 8 }}>
                  <Field label="Commission Rate (%)" value={commission.rate} onChange={e => setCommission({...commission, rate: parseFloat(e.target.value) || 10})} />
                </div>
                <Button variant="contained" onClick={saveCommission} sx={{ alignSelf: 'flex-start', mt: 1 }}>Save Commission</Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}
