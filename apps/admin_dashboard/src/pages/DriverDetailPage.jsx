import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { Box, Typography, Card, CardContent, Grid, Chip, Table, TableBody, TableCell, TableContainer, TableHead, TableRow, Paper, Button, CircularProgress } from '@mui/material';
import { ArrowBack } from '@mui/icons-material';

const API = 'https://zip-rick-4.onrender.com/api/v1';

export default function DriverDetailPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [driver, setDriver] = useState(null);
  const [rides, setRides] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem('admin_token');
        if (!token) return;
        const [dRes, rRes] = await Promise.all([
          fetch(API + '/admin/drivers/' + id, { headers: { Authorization: 'Bearer ' + token } }),
          fetch(API + '/admin/drivers/' + id + '/rides', { headers: { Authorization: 'Bearer ' + token } }),
        ]);
        const dData = await dRes.json();
        const rData = await rRes.json();
        if (dData.success) setDriver(dData.data.driver);
        if (rData.success) setRides(rData.data.rides || []);
      } catch (e) {}
      setLoading(false);
    };
    load();
  }, [id]);

  if (loading) return <Box sx={{ display: 'flex', justifyContent: 'center', p: 8 }}><CircularProgress /></Box>;
  if (!driver) return <Typography>Driver not found</Typography>;

  const u = driver.user || {};
  const v = driver.vehicle || {};
  const docs = driver.documents || [];

  return (
    <Box>
      <Button startIcon={<ArrowBack />} onClick={() => navigate('/drivers')} sx={{ mb: 2 }}>Back to Drivers</Button>
      <Typography variant="h4" sx={{ fontWeight: 700, mb: 3 }}>{u.full_name || 'Driver'}</Typography>

      <Grid container spacing={3}>
        <Grid item xs={12} md={6}>
          <Card><CardContent>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Personal Info</Typography>
            <InfoRow label="Phone" value={u.phone || 'N/A'} />
            <InfoRow label="Email" value={u.email || 'N/A'} />
            <InfoRow label="Status" value={<Chip label={driver.registration_status} color={driver.registration_status === 'approved' ? 'success' : driver.registration_status === 'pending' ? 'warning' : 'error'} size="small" />} />
            <InfoRow label="Online" value={driver.is_online ? 'Yes' : 'No'} />
            <InfoRow label="Joined" value={u.created_at ? new Date(u.created_at).toLocaleDateString() : 'N/A'} />
            <InfoRow label="Active" value={u.is_active ? 'Yes' : 'No'} />
          </CardContent></Card>
        </Grid>

        <Grid item xs={12} md={6}>
          <Card><CardContent>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Vehicle & Earnings</Typography>
            <InfoRow label="Vehicle No" value={v.vehicle_number || 'N/A'} />
            <InfoRow label="Model" value={v.vehicle_model || 'N/A'} />
            <InfoRow label="Total Rides" value={driver.total_rides || 0} />
            <InfoRow label="Total Earnings" value={'₹' + (driver.total_earnings || 0)} />
            <InfoRow label="Rating" value={driver.rating_avg || '0.0'} />
            <InfoRow label="Fee Paid" value={driver.registration_fee_paid ? 'Yes' : 'No'} />
          </CardContent></Card>
        </Grid>

        <Grid item xs={12}>
          <Card><CardContent>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Documents</Typography>
            {docs.length === 0 && <Typography color="text.secondary">No documents uploaded</Typography>}
            <Grid container spacing={1}>
              {docs.map((doc, i) => (
                <Grid item xs={12} sm={6} md={4} key={i}>
                  <Paper variant="outlined" sx={{ p: 2, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <Typography variant="body2">{doc.document_type}</Typography>
                    <Chip label={doc.status || 'pending'} size="small" color={doc.status === 'approved' ? 'success' : 'warning'} />
                  </Paper>
                </Grid>
              ))}
            </Grid>
          </CardContent></Card>
        </Grid>

        <Grid item xs={12}>
          <Card><CardContent>
            <Typography variant="h6" sx={{ fontWeight: 600, mb: 2 }}>Ride History ({rides.length})</Typography>
            <TableContainer>
              <Table size="small">
                <TableHead><TableRow sx={{ bgcolor: '#f5f5f5' }}>
                  <TableCell sx={{ fontWeight: 600 }}>Ride #</TableCell>
                  <TableCell sx={{ fontWeight: 600 }}>Customer</TableCell>
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
                      <TableCell>{r.customer?.user?.full_name || 'N/A'}</TableCell>
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
        <Grid item xs={12}>
          <Card><CardContent>
            <Button variant="contained" color="error" onClick={() => {
              if (window.confirm("Delete this driver and all their data?")) {
                const token = localStorage.getItem("admin_token");
                fetch(API + "/admin/drivers/" + id, { method: "DELETE", headers: { Authorization: "Bearer " + token } }).then(() => navigate("/drivers"));
              }
            }}>Delete This Driver</Button>
          </CardContent></Card>
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
