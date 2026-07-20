import React, { useState, useEffect } from 'react';
import { Box, Typography, Card, CardContent, TextField, Button, Grid, Switch, FormControlLabel, Divider } from '@mui/material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

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
        
        if (fData.success && fData.data?.fare_rates) {
          const saved = fData.data.fare_rates;
          setFare(prev => ({ ...prev, ...saved }));
        }
        if (regData.success && regData.data?.registration_fee) setFee(regData.data.registration_fee);
        if (cData.success && cData.data?.commission) setCommission(cData.data.commission);
      } catch (e) { console.log('Load settings error:', e); }
    };
    loadData();
  }, []);

  const saveFare = async () => {
    try {
      await fetch(API + '/admin/settings/fare', {
        method: 'PUT',
        headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
        body: JSON.stringify(fare),
      });
      setMsg('Fare rates saved successfully!');
    } catch (e) { setMsg('Failed to save'); }
  };

  const saveFee = async () => {
    try {
      await fetch(API + '/admin/settings/registration-fee', {
        method: 'PUT',
        headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
        body: JSON.stringify(fee),
      });
      setMsg('Registration fee saved!');
    } catch (e) { setMsg('Failed to save'); }
  };

  const saveCommission = async () => {
    try {
      await fetch(API + '/admin/settings/commission', {
        method: 'PUT',
        headers: { Authorization: 'Bearer ' + token, 'Content-Type': 'application/json' },
        body: JSON.stringify(commission),
      });
      setMsg('Commission saved!');
    } catch (e) { setMsg('Failed to save'); }
  };

  return (
    <Box>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>System Settings</Typography>
      
      {msg && (
        <Typography sx={{ p: 1.5, bgcolor: '#E8F5E9', borderRadius: 2, mb: 2, color: '#2E7D32' }}>
          {msg}
        </Typography>
      )}

      <Grid container spacing={3}>
        {/* Fare Rates - Single */}
        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2, color: '#6C63FF' }}>
                🚗 Single Ride Fare
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <TextField fullWidth label="Base Fare (₹)" type="number" value={fare.single_base_fare} onChange={e => setFare({...fare, single_base_fare: parseFloat(e.target.value) || 30})} />
                <TextField fullWidth label="Per KM (₹)" type="number" value={fare.single_per_km} onChange={e => setFare({...fare, single_per_km: parseFloat(e.target.value) || 12})} />
                <TextField fullWidth label="Per Minute (₹)" type="number" value={fare.single_per_minute} onChange={e => setFare({...fare, single_per_minute: parseFloat(e.target.value) || 1})} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Fare Rates - Sharing */}
        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2, color: '#00D9A6' }}>
                👥 Sharing Ride Fare
              </Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <TextField fullWidth label="Base Fare (₹)" type="number" value={fare.sharing_base_fare} onChange={e => setFare({...fare, sharing_base_fare: parseFloat(e.target.value) || 20})} />
                <TextField fullWidth label="Per KM (₹)" type="number" value={fare.sharing_per_km} onChange={e => setFare({...fare, sharing_per_km: parseFloat(e.target.value) || 8})} />
                <TextField fullWidth label="Per Minute (₹)" type="number" value={fare.sharing_per_minute} onChange={e => setFare({...fare, sharing_per_minute: parseFloat(e.target.value) || 0.5})} />
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Common Fare Settings */}
        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>⚙️ Common Fare Settings</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <TextField fullWidth label="Minimum Fare (₹)" type="number" value={fare.minimum_fare} onChange={e => setFare({...fare, minimum_fare: parseFloat(e.target.value) || 30})} />
                <TextField fullWidth label="Night Charge Multiplier (1.5 = 50% extra)" type="number" inputProps={{ step: 0.1 }} value={fare.night_charge_multiplier} onChange={e => setFare({...fare, night_charge_multiplier: parseFloat(e.target.value) || 1.5})} />
                <TextField fullWidth label="Peak Multiplier" type="number" inputProps={{ step: 0.1 }} value={fare.peak_multiplier} onChange={e => setFare({...fare, peak_multiplier: parseFloat(e.target.value) || 1.2})} />
                <TextField fullWidth label="Cancellation Fee (₹)" type="number" value={fare.cancellation_fee_customer} onChange={e => setFare({...fare, cancellation_fee_customer: parseFloat(e.target.value) || 10})} />
                <Button variant="contained" onClick={saveFare} sx={{ alignSelf: 'flex-start', mt: 1 }}>Save All Fare Rates</Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>

        {/* Registration Fee + Commission */}
        <Grid item xs={12} md={6}>
          <Card sx={{ height: '100%' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>📋 Registration Fee</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <TextField fullWidth label="Standard Fee (₹)" type="number" value={fee.standard} onChange={e => setFee({...fee, standard: parseFloat(e.target.value) || 999})} />
                <TextField fullWidth label="Promotional Fee (₹)" type="number" value={fee.promotional} onChange={e => setFee({...fee, promotional: parseFloat(e.target.value) || 499})} />
                <FormControlLabel control={<Switch checked={fee.promotion_active} onChange={e => setFee({...fee, promotion_active: e.target.checked})} />} label="Promotion Active" />
                <Button variant="contained" onClick={saveFee} sx={{ alignSelf: 'flex-start' }}>Save Fee</Button>
              </Box>

              <Divider sx={{ my: 3 }} />

              <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>💰 Commission</Typography>
              <Box sx={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                <TextField fullWidth label="Commission Rate (%)" type="number" value={commission.rate} onChange={e => setCommission({...commission, rate: parseFloat(e.target.value) || 10})} />
                <Button variant="contained" onClick={saveCommission} sx={{ alignSelf: 'flex-start' }}>Save Commission</Button>
              </Box>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}
