
const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const multer = require("multer");
const bodyParser = require("body-parser");
const axios = require('axios');   // For calling the Python API
const FormData = require('form-data');
const fs = require('fs');
const path = require('path');


// Configure Multer (Temporary storage for uploaded images)
// This saves the image to a 'uploads' folder so we can read it


const app = express();
app.use(cors());
app.use(bodyParser.json());

// ================= MySQL Connection =================
const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "users_data",
}).promise(); // Use .promise() right away

// Test the connection
(async () => {
    try {
        await db.query('SELECT 1');
        console.log("✅ Connected to MySQL");
    } catch (err) {
        console.error("❌ Error connecting to MySQL:", err);
        process.exit(1);
    }
})();

// ================= Multer Setup =================
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 } // 10MB limit
});


const ALLOWED_FILE_FIELDS = [
  "profilePic",
  "cnicFront",
  "cnicBack",
  "workCert",
  "license",
  "licenseBack",
];


// ================== CUSTOMER ROUTES ==================

// 1. Customer Registration
app.post(
  "/api/customer",
  upload.fields([
    { name: "cnicFront", maxCount: 1 },
    { name: "cnicBack", maxCount: 1 },
    { name: "profilePic", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const { fullName, cnic, phone, city } = req.body;
      const files = req.files || {};
      const sql = `INSERT INTO customers (fullName, cnic, phone, city, cnicFront, cnicBack, profilePic)
                   VALUES (?, ?, ?, ?, ?, ?, ?)`;
      const values = [
        fullName,
        cnic,
        phone,
        city,
        files.cnicFront?.[0]?.buffer || null,
        files.cnicBack?.[0]?.buffer || null,
        files.profilePic?.[0]?.buffer || null,
      ];

      const [result] = await db.query(sql, values);
      res.status(201).json({ customerId: result.insertId });
    } catch (err) {
      console.error("❌ Insert customer error:", err);
      res.status(500).json({ error: "Failed to save customer data" });
    }
  }
);

// 2. Get Customer by ID
app.get("/api/customer/:id", async (req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM customers WHERE id = ?", [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: "Customer not found" });

    const customer = rows[0];
    const toBase64 = (buffer) => (buffer ? buffer.toString("base64") : null);

    res.json({
      ...customer,
      cnicFront: toBase64(customer.cnicFront),
      cnicBack: toBase64(customer.cnicBack),
      profilePic: toBase64(customer.profilePic),
    });
  } catch (err) {
    console.error("❌ Error fetching customer:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// 3. Update Customer Document
app.put(
  "/api/customer/:id/documents",
  upload.single("file"), // Expects a single file with field name 'file'
  async (req, res) => {
    const { id } = req.params;
    const { field } = req.query;
    const file = req.file;

    if (!field || !ALLOWED_FILE_FIELDS.includes(field)) {
      return res.status(400).json({ error: `Invalid 'field' query.` });
    }
    if (!file) {
      return res.status(400).json({ error: "No file uploaded (use form field 'file')" });
    }

    try {
      const sql = `UPDATE customers SET ${field} = ? WHERE id = ?`;
      const [result] = await db.query(sql, [file.buffer, id]);
      if (result.affectedRows === 0) return res.status(404).json({ error: "Customer not found" });
      res.json({ message: "Customer document updated successfully" });
    } catch (err) {
      console.error("❌ Error updating customer document:", err);
      res.status(500).json({ error: "Server error while updating document" });
    }
  }
);

// 4. Delete Customer Document
app.delete("/api/customer/:id/documents", async (req, res) => {
  const { id } = req.params;
  const { field } = req.query;

  if (!field || !ALLOWED_FILE_FIELDS.includes(field)) {
    return res.status(400).json({ error: `Invalid or missing 'field' query.` });
  }

  try {
    const sql = `UPDATE customers SET ${field} = NULL WHERE id = ?`;
    const [result] = await db.query(sql, [id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: "Customer not found" });
    res.json({ message: "Customer document deleted successfully" });
  } catch (err) {
    console.error("❌ Error deleting customer document:", err);
    res.status(500).json({ error: "Server error" });
  }
});


// ================== WORKER ROUTES ==================

// 1. Worker Registration
app.post(
  "/api/worker",
  upload.fields([
    { name: "cnicFront", maxCount: 1 },
    { name: "cnicBack", maxCount: 1 },
    { name: "profilePic", maxCount: 1 },
    { name: "workCert", maxCount: 1 },
    { name: "license", maxCount: 1 },
    { name: "licenseBack", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const { fullName, cnic, phone, city, skill, availableHours, about } = req.body;
      const files = req.files || {};
      const sql = `INSERT INTO workers (fullName, cnic, phone, city, skill, availableHours, about, cnicFront, cnicBack, profilePic, workCert, license, licenseBack, worker_form_completed)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`;
      const values = [
        fullName, cnic, phone, city, skill, availableHours, about || null,
        files.cnicFront?.[0]?.buffer || null,
        files.cnicBack?.[0]?.buffer || null,
        files.profilePic?.[0]?.buffer || null,
        files.workCert?.[0]?.buffer || null,
        files.license?.[0]?.buffer || null,
        files.licenseBack?.[0]?.buffer || null,
        true,
      ];
      const [result] = await db.query(sql, values);
      res.json({ workerId: result.insertId });
    } catch (err) {
      console.error("❌ Worker insert error:", err);
      res.status(500).json({ error: "Failed to save worker" });
    }
  }
);

// 2. Get Worker by ID
app.get("/api/worker/:id", async (req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM workers WHERE id = ?", [req.params.id]);
    if (rows.length === 0) return res.status(404).json({ error: "Worker not found" });

    const worker = rows[0];
    const toBase64 = (buffer) => (buffer ? buffer.toString("base64") : null);

    res.json({
      ...worker,
      cnicFront: toBase64(worker.cnicFront),
      cnicBack: toBase64(worker.cnicBack),
      profilePic: toBase64(worker.profilePic),
      workCert: toBase64(worker.workCert),
      license: toBase64(worker.license),
      licenseBack: toBase64(worker.licenseBack),
    });
  } catch (err) {
    console.error("❌ Fetch worker error:", err);
    res.status(500).json({ error: "Failed to fetch worker" });
  }
});

// 3. Update Worker Document
app.put(
  "/api/worker/:id/documents",
  upload.single("file"),
  async (req, res) => {
    const { id } = req.params;
    const { field } = req.query;
    const file = req.file;
    if (!field || !ALLOWED_FILE_FIELDS.includes(field)) {
      return res.status(400).json({ error: `Invalid 'field' query.` });
    }
    if (!file) {
      return res.status(400).json({ error: "No file uploaded" });
    }

    try {
      const sql = `UPDATE workers SET ${field} = ? WHERE id = ?`;
      const [result] = await db.query(sql, [file.buffer, id]);
      if (result.affectedRows === 0) return res.status(404).json({ error: "Worker not found" });
      res.json({ message: "Document updated successfully" });
    } catch (err) {
      console.error("❌ Error updating document:", err);
      res.status(500).json({ error: "Server error while updating document" });
    }
  }
);

// 4. Delete Worker Document
app.delete("/api/worker/:id/documents", async (req, res) => {
  const { id } = req.params;
  const { field } = req.query;
  if (!field || !ALLOWED_FILE_FIELDS.includes(field)) {
    return res.status(400).json({ error: `Invalid 'field' query.` });
  }

  try {
    const sql = `UPDATE workers SET ${field} = NULL WHERE id = ?`;
    const [result] = await db.query(sql, [id]);
    if (result.affectedRows === 0) return res.status(404).json({ error: "Worker not found" });
    res.json({ message: "File deleted successfully" });
  } catch (err) {
    console.error("❌ Error deleting document:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// ================== JOB ROUTES ==================
// 1. POST: Customer Posts a Job
app.post('/api/jobs', async (req, res) => {
    try {
        const { customerId, title, description, budget, location } = req.body;

        // --- FIX: Use the actual customerId from the request ---
        if (!customerId || !title || !description || !budget) {
            return res.status(400).json({ error: "Customer ID and all job fields are required." });
        }

        const sql = `INSERT INTO jobs (customer_id, title, description, budget, location) VALUES (?, ?, ?, ?, ?)`;
        const [result] = await db.query(sql, [customerId, title, description, budget, location]);

        res.status(201).json({ message: "Job Posted Successfully", jobId: result.insertId });
    } catch (err) {
        console.error("❌ Job post error:", err);
        res.status(500).json({ error: "Database error" });
    }
});


// 3. PUT: Worker Accepts a Job
app.put('/api/jobs/:id/accept', async (req, res) => {
    const jobId = req.params.id;
    const { workerId } = req.body;
    if (!workerId) {
        return res.status(400).json({ error: "Worker ID is required to accept a job." });
    }
    try {
        const sql = `UPDATE jobs SET status = 'assigned', worker_id = ? WHERE id = ? AND status = 'open'`;
        const [result] = await db.query(sql, [workerId, jobId]);
        if (result.affectedRows === 0) {
            return res.status(404).json({ error: "Job not found or already assigned." });
        }
        res.json({ message: "Job Accepted!" });
    } catch (err) {
        console.error("Error accepting job:", err);
        return res.status(500).json({ error: "Database update failed" });
    }
});

// 2. GET: Worker Sees All Open Jobs with Customer Details
app.get('/api/jobs/open', async (req, res) => {
    try {
        const sql = `
            SELECT
                j.id, j.title, j.description, j.budget, j.location, j.created_at,
                c.fullName AS customerName,
                c.phone AS customerPhone,
                c.profilePic AS customerPic
            FROM jobs AS j
            INNER JOIN customers AS c ON j.customer_id = c.id
            WHERE j.status = 'open'
            ORDER BY j.created_at DESC
        `;
        const [rows] = await db.query(sql);

        // --- FIX: Correctly map and convert buffer to base64 ---
        const jobsWithPics = rows.map(job => ({
            ...job,
            customerPic: job.customerPic ? Buffer.from(job.customerPic).toString('base64') : null
        }));
        res.json(jobsWithPics);
    } catch (err) {
        console.error("❌ Fetch open jobs error:", err);
        res.status(500).json({ error: "Failed to fetch jobs" });
    }
});

// 4. GET: Fetch jobs posted by a specific customer
app.get('/api/jobs/customer/:id', async (req, res) => {
    const customerId = req.params.id;
    try {
        const sql = `SELECT * FROM jobs WHERE customer_id = ? ORDER BY created_at DESC`;
        const [rows] = await db.query(sql, [customerId]);
        res.json(rows);
    } catch (err) {
        console.error("Error fetching customer jobs:", err);
        res.status(500).json({ error: "Database error" });
    }
});

// 5. OCR LOGIC

// Configure Multer (Temporary storage for uploaded images)
// This saves the image to a 'uploads' folder so we can read it
// 1. Create a unique uploader just for the CNIC feature
const cnicUpload = multer({ dest: 'uploads/' });

// --- THE NEW ROUTE ---
// 2. Change 'upload.single' to 'cnicUpload.single'
app.post('/api/verify-cnic', cnicUpload.single('cnic_image'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ success: false, message: 'No image uploaded' });
        }

        console.log("Received image:", req.file.filename);

        // Prepare the image to send to the Python Microservice
        const formData = new FormData();
        formData.append('file', fs.createReadStream(req.file.path));

        // Send to Python
        const pythonResponse = await axios.post('http://127.0.0.1:8000/extract-cnic', formData, {
            headers: {
                ...formData.getHeaders()
            }
        });

        // Cleanup: Delete the temp file to save space
        fs.unlinkSync(req.file.path);

        // Send the Python result back to Flutter
        console.log("AI Response:", pythonResponse.data);
        res.json(pythonResponse.data);

    } catch (error) {
        console.error("Error connecting to AI service:", error.message);

        if (req.file && req.file.path && fs.existsSync(req.file.path)) {
            fs.unlinkSync(req.file.path);
        }

        res.status(500).json({
            success: false,
            message: 'Failed to process CNIC. Is the AI service running?'
        });
    }
});

// --- NEW ROUTE: AI VOICE ASSISTANT ---
// Note: Isme hum file upload (multer) use nahi kar rahe kyunke hum sirf text bhej rahe hain.
app.post('/api/process-voice', express.json(), async (req, res) => {
    try {
        const userText = req.body.text;

        if (!userText) {
            return res.status(400).json({ success: false, message: 'No text provided' });
        }

        console.log("Flutter sent voice text:", userText);

        // Send this text to Python
        const pythonResponse = await axios.post('http://127.0.0.1:8000/process-voice-text', {
            text: userText
        });

        // Send Python's smart JSON back to Flutter
        res.json(pythonResponse.data);

    } catch (error) {
        console.error("Error connecting to Voice AI:", error.message);
        res.status(500).json({ success: false, message: 'Voice processing failed' });
    }
});

// 2. GET: Worker Sees Open Jobs (Filtered by City and Skill)
app.get('/api/jobs/open', async (req, res) => {
    try {
        // Get filters from the URL query strings
        const { city, skill } = req.query;

        let sql = `
            SELECT
                j.id, j.title, j.description, j.budget, j.location, j.created_at,
                c.fullName AS customerName,
                c.phone AS customerPhone,
                c.profilePic AS customerPic
            FROM jobs AS j
            INNER JOIN customers AS c ON j.customer_id = c.id
            WHERE j.status = 'open'
        `;

        const params = [];

        // Logical Filter: Location
        if (city && city !== "null" && city !== "") {
            sql += ` AND j.location = ?`;
            params.push(city);
        }

        // Logical Filter: Skill Match
        // We use LIKE because a job title or description might contain the skill name
        if (skill && skill !== "null" && skill !== "") {
            sql += ` AND (j.title LIKE ? OR j.description LIKE ?)`;
            params.push(`%${skill}%`, `%${skill}%`);
        }

        sql += ` ORDER BY j.created_at DESC`;

        const [rows] = await db.query(sql, params);

        const jobsWithPics = rows.map(job => ({
            ...job,
            customerPic: job.customerPic ? Buffer.from(job.customerPic).toString('base64') : null
        }));

        res.json(jobsWithPics);
    } catch (err) {
        console.error("❌ Fetch open jobs error:", err);
        res.status(500).json({ error: "Failed to fetch jobs" });
    }
});
// ================== START SERVER ==================
const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`✅ Server running on port ${PORT}. All routes registered.`));
