import React, { useState, useEffect } from 'react';

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
    <div style={{ padding: 24, fontFamily: 'sans-serif' }}>
      <h1>System Settings</h1>
      {msg && <div style={{ padding: 8, background: '#E8F5E9', borderRadius: 8, marginBottom: 12, color: '#2E7D32' }}>{msg}</div>}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(300px, 1fr))', gap: 16 }}>
        <div style={{ background: 'white', borderRadius: 12, padding: 24, boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
          <h3>Fare Rates</h3>
          <label>Base Fare (Rs): <input type="number" value={fare.base_fare} onChange={e => setFare({...fare, base_fare: e.target.value})} style={{ width: '100%', padding: 8, margin: '8px 0', borderRadius: 4, border: '1px solid #ccc' }} /></label>
          <label>Per KM (Rs): <input type="number" value={fare.per_km} onChange={e => setFare({...fare, per_km: e.target.value})} style={{ width: '100%', padding: 8, margin: '8px 0', borderRadius: 4, border: '1px solid #ccc' }} /></label>
          <label>Per Minute (Rs): <input type="number" value={fare.per_minute} onChange={e => setFare({...fare, per_minute: e.target.value})} style={{ width: '100%', padding: 8, margin: '8px 0', borderRadius: 4, border: '1px solid #ccc' }} /></label>
          <label>Min Fare (Rs): <input type="number" value={fare.minimum_fare} onChange={e => setFare({...fare, minimum_fare: e.target.value})} style={{ width: '100%', padding: 8, margin: '8px 0', borderRadius: 4, border: '1px solid #ccc' }} /></label>
          <button onClick={saveFare} style={{ padding: '10px 20px', background: '#6C63FF', color: 'white', border: 'none', borderRadius: 8, cursor: 'pointer', marginTop: 12 }}>Save Fare</button>
        </div>
        <div style={{ background: 'white', borderRadius: 12, padding: 24, boxShadow: '0 2px 8px rgba(0,0,0,0.1)' }}>
          <h3>Registration Fee</h3>
          <label>Standard Fee (Rs): <input type="number" value={fee.standard} onChange={e => setFee({...fee, standard: parseFloat(e.target.value) || 999})} style={{ width: '100%', padding: 8, margin: '8px 0', borderRadius: 4, border: '1px solid #ccc' }} /></label>
          <label>Promotional Fee (Rs): <input type="number" value={fee.promotional} onChange={e => setFee({...fee, promotional: parseFloat(e.target.value) || 499})} style={{ width: '100%', padding: 8, margin: '8px 0', borderRadius: 4, border: '1px solid #ccc' }} /></label>
          <label><input type="checkbox" checked={fee.promotion_active} onChange={e => setFee({...fee, promotion_active: e.target.checked})} /> Promotion Active</label>
          <button onClick={saveFee} style={{ padding: '10px 20px', background: '#6C63FF', color: 'white', border: 'none', borderRadius: 8, cursor: 'pointer', marginTop: 12, display: 'block' }}>Save Fee</button>
          <hr style={{ margin: '16px 0' }} />
          <h3>Commission</h3>
          <label>Rate (%): <input type="number" value={commission.rate} onChange={e => setCommission({...commission, rate: parseFloat(e.target.value) || 10})} style={{ width: '100%', padding: 8, margin: '8px 0', borderRadius: 4, border: '1px solid #ccc' }} /></label>
          <button onClick={saveCommission} style={{ padding: '10px 20px', background: '#6C63FF', color: 'white', border: 'none', borderRadius: 8, cursor: 'pointer', marginTop: 12 }}>Save Commission</button>
        </div>
      </div>
    </div>
  );
}