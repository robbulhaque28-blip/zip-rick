import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Box, Typography, Card, CardContent, Grid, Chip, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Button, CircularProgress } from '@mui/material';
import { ArrowBack } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function CustomerDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        const res = await fetch(API + '/admin/customers/' + id, { headers: { Authorization: 'Bearer ' + token } });
        const d = await res.json();
        if (d.success) setData(d.data);
      } catch (e) {}
      setLoading(false);
    };
    load();
  }, [id]);

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', p: 8 }}><CircularProgress /></Box>;
  if (!data) return <Typography>Customer not found</Typography>;

  const c = data.customer || {};
  const u = c.user || {};
  const rides = data.rides || [];

  return (
    <Box>
      <Button startIcon={<ArrowBack />} onClick={() => navigate('/customers')} sx={{ mb: 2 }}>Back to Customers</Button>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>{u.full_name || 'Customer'}</Typography>

      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card><CardContent>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Customer Info</Typography>
            <InfoRow label="Phone" value={u.phone || 'N/A'} />
            <InfoRow label="Email" value={u.email || 'N/A'} />
            <InfoRow label="Total Rides" value={c.total_rides || 0} />
            <InfoRow label="Total Spent" value={'₹' + (c.total_spent || 0)} />
            <InfoRow label="Rating" value={c.rating || '0.0'} />
            <InfoRow label="Joined" value={u.created_at ? new Date(u.created_at).toLocaleDateString() : 'N/A'} />
            <InfoRow label="Referral Code" value={c.referral_code || 'N/A'} />
            <InfoRow label="Loyalty Points" value={c.loyalty_points || 0} />
          </CardContent></Card>
        </Grid>

        <Grid item xs={12}>
          <Card><CardContent>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Ride History ({rides.length})</Typography>
            <TableContainer>
              <Table size="small">
                <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
                  <TableCell sx={{ fontWeight: 600 }}>Ride #</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Driver</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Pickup</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Drop</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Fare</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Status</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Date</TableCell>
                </TableRow></TableHead>
                <TableBody>
                  {rides.length === 0 && <TableRow><TableCell colSpan={7} sx={{ textAlign: 'center', py: 3, color: '#999' }}>No rides yet</TableCell></TableRow>}
                  {rides.map(r => (
                    <TableRow key={r.id}>
                      <TableCell>{r.ride_number || 'N/A'}</TableCell>
                      <TableCell>{r.driver?.user?.full_name || 'N/A'}</TableCell>
                      <TableCell sx={{ maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.pickup_address || ''}</TableCell>
                      <TableCell sx={{ maxWidth: 120, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{r.drop_address || ''}</TableCell>
                      <TableCell>₹{r.total_fare || 0}</TableCell>
                      <TableCell><Chip label={r.status} size="small" color={r.status === 'completed' ? 'success' : r.status === 'cancelled' ? 'error' : 'warning'} /></TableCell>
                      <TableCell>{r.created_at ? new Date(r.created_at).toLocaleDateString() : ''}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </TableContainer>
          </CardContent></Card>
        </Grid>
      </Grid>
    </Box>
  );
}

        <Grid item xs={12}>
          <Card sx={{ border: '2px solid #f44336' }}>
            <CardContent sx={{ p: 3 }}>
              <Typography variant="h6" sx={{ fontWeight: 600, mb: 1, color: '#f44336' }}>Danger Zone</Typography>
              <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
                Permanently delete this customer and all their data.
              </Typography>
              <Button variant="contained" color="error" onClick={() => {
                if (!window.confirm('Delete this customer and all their data? This cannot be undone!')) return;
                const token = localStorage.getItem('admin_token');
                fetch(API + '/admin/customers/' + id, { method: 'DELETE', headers: { Authorization: 'Bearer ' + token } }).then(() => navigate('/customers'));
              }}>Delete Customer</Button>
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Box>
  );
}

function InfoRow({ label, value }) {
  return (
    <Box sx={{ display: 'flex', justifyContent: 'space-between', py: 0.5, borderBottom: '1px solid #f0f0f0' }}>
      <Typography variant="body2" color="text.secondary">{label}</Typography>
      <Typography variant="body2" sx={{ fontWeight: 500 }}>{value}</Typography>
    </Box>
  );
}
