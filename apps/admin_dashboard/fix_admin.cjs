const fs = require("fs");
const path = require("path");
const base = "C:\\Users\\Lenovo\\Documents\\home\\user\\zip-rick\\apps\\admin_dashboard\\src\\pages";

// Write DashboardPage - simple, clean, no HTML entities
const dashboard = `
import React, { useState, useEffect } from "react";

const API = "http://localhost:3000/api/v1";

export default function DashboardPage() {
  const [stats, setStats] = useState({
    total_customers: 0, total_drivers: 0, pending_drivers: 0,
    active_rides: 0, today_rides: 0, revenue: { total: 0, today: 0 }
  });
  const [error, setError] = useState("");

  const loadData = async () => {
    try {
      const token = localStorage.getItem("admin_token");
      if (!token) { setError("Not logged in"); return; }
      const res = await fetch(API + "/admin/dashboard", {
        headers: { Authorization: "Bearer " + token }
      });
      const data = await res.json();
      if (data.success && data.data && data.data.overview) {
        setStats(data.data.overview);
        setError("");
      } else if (res.status === 401) {
        setError("Session expired. Please login again.");
      }
    } catch (e) {
      setError("Cannot connect to server");
    }
  };

  useEffect(() => { loadData(); }, []);

  return (
    <div style={{ padding: 24, fontFamily: "sans-serif" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 24 }}>
        <h1 style={{ margin: 0 }}>Zip-Rick Dashboard</h1>
        <button onClick={loadData} style={{ padding: "8px 16px", background: "#6C63FF", color: "white", border: "none", borderRadius: 8, cursor: "pointer" }}>
          Refresh
        </button>
      </div>
      {error && <div style={{ padding: 12, background: "#FFE0E0", borderRadius: 8, marginBottom: 16, color: "#D32F2F" }}>{error}</div>}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(200px, 1fr))", gap: 16, marginBottom: 24 }}>
        <Card title="Total Customers" value={stats.total_customers} color="#6C63FF" />
        <Card title="Total Drivers" value={stats.total_drivers} color="#00D9A6" />
        <Card title="Active Rides" value={stats.active_rides} color="#FFA726" />
        <Card title="Revenue Today" value={"\u20B9" + (stats.revenue?.today || 0)} color="#66BB6A" />
      </div>
    </div>
  );
}

function Card({ title, value, color }) {
  return (
    <div style={{ padding: 24, borderRadius: 12, boxShadow: "0 2px 8px rgba(0,0,0,0.1)", background: "white" }}>
      <p style={{ color: "#666", margin: "0 0 8px 0", fontSize: 14 }}>{title}</p>
      <h2 style={{ margin: 0, color: color }}>{value || 0}</h2>
    </div>
  );
}
`;

fs.writeFileSync(path.join(base, "DashboardPage.jsx"), dashboard.trim());
console.log("DashboardPage written");

// Write DriversPage
const drivers = `
import React, { useState, useEffect } from "react";

const API = "http://localhost:3000/api/v1";

export default function DriversPage() {
  const [drivers, setDrivers] = useState([]);
  const [filter, setFilter] = useState("");
  const [msg, setMsg] = useState("");

  const load = async () => {
    try {
      const token = localStorage.getItem("admin_token");
      if (!token) return;
      let url = API + "/admin/drivers?limit=100";
      if (filter) url += "&status=" + filter;
      const res = await fetch(url, { headers: { Authorization: "Bearer " + token } });
      const data = await res.json();
      if (data.success && Array.isArray(data.data)) setDrivers(data.data);
    } catch (e) {}
  };

  useEffect(() => { load(); }, [filter]);

  const approve = async (id) => {
    const token = localStorage.getItem("admin_token");
    await fetch(API + "/admin/drivers/" + id + "/approve", { method: "POST", headers: { Authorization: "Bearer " + token } });
    setMsg("Driver approved!");
    load();
  };

  const reject = async (id) => {
    const token = localStorage.getItem("admin_token");
    await fetch(API + "/admin/drivers/" + id + "/reject", { method: "POST", headers: { Authorization: "Bearer " + token } });
    setMsg("Driver rejected!");
    load();
  };

  return (
    <div style={{ padding: 24, fontFamily: "sans-serif" }}>
      <h1>Driver Management</h1>
      {msg && <div style={{ padding: 8, background: "#E8F5E9", borderRadius: 8, marginBottom: 12, color: "#2E7D32" }}>{msg}</div>}
      <select onChange={e => setFilter(e.target.value)} style={{ padding: "8px 16px", marginBottom: 16, borderRadius: 8, border: "1px solid #ccc", fontSize: 14 }}>
        <option value="">All Drivers</option>
        <option value="pending">Pending Approval</option>
        <option value="approved">Approved</option>
        <option value="rejected">Rejected</option>
      </select>
      <table style={{ width: "100%", borderCollapse: "collapse", background: "white", borderRadius: 8, overflow: "hidden", boxShadow: "0 2px 8px rgba(0,0,0,0.1)" }}>
        <thead>
          <tr style={{ background: "#f5f5f5", textAlign: "left" }}>
            <th style={{ padding: 12 }}>Name</th>
            <th style={{ padding: 12 }}>Phone</th>
            <th style={{ padding: 12 }}>Status</th>
            <th style={{ padding: 12 }}>Documents</th>
            <th style={{ padding: 12 }}>Fee</th>
            <th style={{ padding: 12 }}>Actions</th>
          </tr>
        </thead>
        <tbody>
          {drivers.length === 0 && <tr><td colSpan="6" style={{ padding: 24, textAlign: "center", color: "#999" }}>No drivers found</td></tr>}
          {drivers.map(d => (
            <tr key={d.id} style={{ borderBottom: "1px solid #eee" }}>
              <td style={{ padding: 12 }}>{d.user ? d.user.full_name : "N/A"}</td>
              <td style={{ padding: 12 }}>{d.user ? d.user.phone : "N/A"}</td>
              <td style={{ padding: 12 }}>{d.registration_status}</td>
              <td style={{ padding: 12 }}>{d.is_documents_uploaded ? "Yes" : "No"}</td>
              <td style={{ padding: 12 }}>{d.registration_fee_paid ? "Paid" : "Pending"}</td>
              <td style={{ padding: 12 }}>
                {d.registration_status === "pending" && (
                  <span>
                    <button onClick={() => approve(d.id)} style={{ padding: "4px 12px", background: "#4CAF50", color: "white", border: "none", borderRadius: 4, cursor: "pointer", marginRight: 8 }}>Approve</button>
                    <button onClick={() => reject(d.id)} style={{ padding: "4px 12px", background: "#f44336", color: "white", border: "none", borderRadius: 4, cursor: "pointer" }}>Reject</button>
                  </span>
                )}
                {d.registration_status === "approved" && <span style={{ color: "#4CAF50" }}>Active</span>}
                {d.registration_status === "rejected" && <span style={{ color: "#f44336" }}>Rejected</span>}
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
`;

fs.writeFileSync(path.join(base, "DriversPage.jsx"), drivers.trim());
console.log("DriversPage written");

// Write CustomersPage
const customers = `
import React, { useState, useEffect } from "react";

const API = "http://localhost:3000/api/v1";

export default function CustomersPage() {
  const [customers, setCustomers] = useState([]);

  useEffect(() => {
    const load = async () => {
      try {
        const token = localStorage.getItem("admin_token");
        if (!token) return;
        const res = await fetch(API + "/admin/customers?limit=100", { headers: { Authorization: "Bearer " + token } });
        const data = await res.json();
        if (data.success && Array.isArray(data.data)) setCustomers(data.data);
      } catch (e) {}
    };
    load();
  }, []);

  return (
    <div style={{ padding: 24, fontFamily: "sans-serif" }}>
      <h1>Customer Management</h1>
      <p style={{ color: "#666", marginBottom: 16 }}>Total: {customers.length} customers</p>
      <table style={{ width: "100%", borderCollapse: "collapse", background: "white", borderRadius: 8, overflow: "hidden", boxShadow: "0 2px 8px rgba(0,0,0,0.1)" }}>
        <thead>
          <tr style={{ background: "#f5f5f5", textAlign: "left" }}>
            <th style={{ padding: 12 }}>Name</th>
            <th style={{ padding: 12 }}>Phone</th>
            <th style={{ padding: 12 }}>Rides</th>
            <th style={{ padding: 12 }}>Spent</th>
            <th style={{ padding: 12 }}>Rating</th>
            <th style={{ padding: 12 }}>Joined</th>
          </tr>
        </thead>
        <tbody>
          {customers.length === 0 && <tr><td colSpan="6" style={{ padding: 24, textAlign: "center", color: "#999" }}>No customers found</td></tr>}
          {customers.map(c => (
            <tr key={c.id} style={{ borderBottom: "1px solid #eee" }}>
              <td style={{ padding: 12 }}>{c.user ? c.user.full_name : "N/A"}</td>
              <td style={{ padding: 12 }}>{c.user ? c.user.phone : "N/A"}</td>
              <td style={{ padding: 12 }}>{c.total_rides || 0}</td>
              <td style={{ padding: 12 }}>Rs {c.total_spent || 0}</td>
              <td style={{ padding: 12 }}>{c.rating || "0.0"}</td>
              <td style={{ padding: 12 }}>{c.created_at ? new Date(c.created_at).toLocaleDateString() : "N/A"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
`;

fs.writeFileSync(path.join(base, "CustomersPage.jsx"), customers.trim());
console.log("CustomersPage written");

console.log("All admin pages written successfully!");
