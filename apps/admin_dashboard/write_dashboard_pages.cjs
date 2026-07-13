const fs = require("fs");

const driversContent = 
'import React, { useState, useEffect } from "react";\n' +
'const API = "http://localhost:3000/api/v1";\n' +
'export default function DriversPage() {\n' +
'  const [drivers, setDrivers] = useState([]);\n' +
'  const [filter, setFilter] = useState("");\n' +
'  const loadDrivers = async () => {\n' +
'    try {\n' +
'      const token = localStorage.getItem("admin_token");\n' +
'      if (!token) return;\n' +
'      let url = API + "/admin/drivers?limit=50";\n' +
'      if (filter) url += "&status=" + filter;\n' +
'      const res = await fetch(url, { headers: { Authorization: "Bearer " + token } });\n' +
'      const data = await res.json();\n' +
'      if (data.success && Array.isArray(data.data)) setDrivers(data.data);\n' +
'    } catch(e) { console.log(e); }\n' +
'  };\n' +
'  useEffect(() => { loadDrivers(); }, [filter]);\n' +
'  return (\n' +
'    <div style={{ padding: 24 }}>\n' +
'      <h1>Driver Management</h1>\n' +
'      <select onChange={e => setFilter(e.target.value)} style={{ marginBottom: 16, padding: 8 }}>\n' +
'        <option value="">All</option>\n' +
'        <option value="pending">Pending</option>\n' +
'        <option value="approved">Approved</option>\n' +
'        <option value="rejected">Rejected</option>\n' +
'      </select>\n' +
'      <table border="1" cellPadding="8" style={{ width: "100%", borderCollapse: "collapse" }}>\n' +
'        <thead><tr style={{ background: "#f0f0f0" }}>\n' +
'          <th>Name</th><th>Phone</th><th>Status</th><th>Actions</th>\n' +
'        </tr></thead>\n' +
'        <tbody>\n' +
'          {drivers.length === 0 && <tr><td colSpan={4} style={{ textAlign: "center" }}>No drivers found</td></tr>}\n' +
'          {drivers.map(d => (\n' +
'            <tr key={d.id}>\n' +
'              <td>{d.user ? d.user.full_name : "N/A"}</td>\n' +
'              <td>{d.user ? d.user.phone : "N/A"}</td>\n' +
'              <td>{d.registration_status}</td>\n' +
'              <td>\n' +
'                {d.registration_status === "pending" && (\n' +
'                  <>\n' +
'                    <button onClick={async () => { const t = localStorage.getItem("admin_token"); await fetch(API + "/admin/drivers/" + d.id + "/approve", { method: "POST", headers: { Authorization: "Bearer " + t } }); loadDrivers(); }} style={{ color: "green", marginRight: 8 }}>Approve</button>\n' +
'                    <button onClick={async () => { const t = localStorage.getItem("admin_token"); await fetch(API + "/admin/drivers/" + d.id + "/reject", { method: "POST", headers: { Authorization: "Bearer " + t } }); loadDrivers(); }} style={{ color: "red" }}>Reject</button>\n' +
'                  </>\n' +
'                )}\n' +
'              </td>\n' +
'            </tr>\n' +
'          ))}\n' +
'        </tbody>\n' +
'      </table>\n' +
'    </div>\n' +
'  );\n' +
'}\n';

const customersContent = 
'import React, { useState, useEffect } from "react";\n' +
'const API = "http://localhost:3000/api/v1";\n' +
'export default function CustomersPage() {\n' +
'  const [customers, setCustomers] = useState([]);\n' +
'  useEffect(() => {\n' +
'    const load = async () => {\n' +
'      try {\n' +
'        const token = localStorage.getItem("admin_token");\n' +
'        if (!token) return;\n' +
'        const res = await fetch(API + "/admin/customers?limit=50", { headers: { Authorization: "Bearer " + token } });\n' +
'        const data = await res.json();\n' +
'        if (data.success && Array.isArray(data.data)) setCustomers(data.data);\n' +
'      } catch(e) { console.log(e); }\n' +
'    };\n' +
'    load();\n' +
'  }, []);\n' +
'  return (\n' +
'    <div style={{ padding: 24 }}>\n' +
'      <h1>Customer Management</h1>\n' +
'      <table border="1" cellPadding="8" style={{ width: "100%", borderCollapse: "collapse" }}>\n' +
'        <thead><tr style={{ background: "#f0f0f0" }}>\n' +
'          <th>Name</th><th>Phone</th><th>Rides</th><th>Spent</th><th>Rating</th>\n' +
'        </tr></thead>\n' +
'        <tbody>\n' +
'          {customers.length === 0 && <tr><td colSpan={5} style={{ textAlign: "center" }}>No customers found</td></tr>}\n' +
'          {customers.map(c => (\n' +
'            <tr key={c.id}>\n' +
'              <td>{c.user ? c.user.full_name : "N/A"}</td>\n' +
'              <td>{c.user ? c.user.phone : "N/A"}</td>\n' +
'              <td>{c.total_rides || 0}</td>\n' +
'              <td>{"Rs " + (c.total_spent || 0)}</td>\n' +
'              <td>{c.rating || "0.0"}</td>\n' +
'            </tr>\n' +
'          ))}\n' +
'        </tbody>\n' +
'      </table>\n' +
'    </div>\n' +
'  );\n' +
'}\n';

fs.writeFileSync("src/pages/DriversPage.jsx", driversContent);
fs.writeFileSync("src/pages/CustomersPage.jsx", customersContent);
console.log("Both files written successfully");
