
const express = require("express");
const mysql = require("mysql2");
const cors = require("cors");
const multer = require("multer");
const path = require("path");
const bodyParser = require("body-parser");
const fs = require("fs");

const app = express();
app.use(cors());
app.use(bodyParser.json());


const uploadDir = path.join(__dirname, "uploads");
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir);
}
app.use("/uploads", express.static(uploadDir));

// ================= MySQL Connection =================
const db = mysql.createConnection({
  host: "localhost",
  user: "root",
  password: "",
  database: "users_data",
});


const dbp = db.promise();

db.connect((err) => {
  if (err) {
    console.error("❌ Error connecting to MySQL:", err);
    process.exit(1);
  } else {
    console.log("✅ Connected to MySQL");
  }
});

// ================= Multer Setup =================
const upload = multer({
  storage: multer.memoryStorage(), 
  limits: { fileSize: 10 * 1024 * 1024 } 
});


const ALLOWED_FILE_FIELDS = [
  "profilePic",
  "cnicFront",
  "cnicBack",
  "workCert",
  "license",
  "licenseBack",
];

// ================== Customer Registration ==================

app.post(
  "/api/customer",
  upload.fields([
    { name: "cnicFront", maxCount: 1 },
    { name: "cnicBack", maxCount: 1 },
    { name: "profilepic", maxCount: 1 }, 
  ]),
  async (req, res) => {
    try {
      const { fullName, cnic, phone, city } = req.body;

      const cnicFront = req.files?.["cnicFront"]?.[0]?.filename || null;
      const cnicBack = req.files?.["cnicBack"]?.[0]?.filename || null;
      const profilepic = req.files?.["profilepic"]?.[0]?.filename || null;

      const sql = `INSERT INTO customers (fullName, cnic, phone, city, cnicFront, cnicBack, profilepic)
                   VALUES (?, ?, ?, ?, ?, ?, ?)`;

      const [result] = await dbp.query(sql, [
        fullName,
        cnic,
        phone,
        city,
        cnicFront,
        cnicBack,
        profilepic,
      ]);

      res.status(201).json({
        message: "✅ Customer data saved successfully!",
        id: result.insertId,
      });
    } catch (err) {
      console.error("❌ Insert customer error:", err);
      res.status(500).json({ error: "Failed to save customer data" });
    }
  }
);

app.get("/api/customer/:id", async (req, res) => {
  try {
    const [rows] = await dbp.query("SELECT * FROM customers WHERE id = ?", [req.params.id]);
    if (rows.length === 0) {
      return res.status(404).json({ error: "Customer not found" });
    }
    res.json(rows[0]);
  } catch (err) {
    console.error("❌ Error fetching customer:", err);
    res.status(500).json({ error: "Server error" });
  }
});

// ================== Worker Registration ==================
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

      const sql = `
        INSERT INTO workers
        (fullName, cnic, phone, city, skill, availableHours, about,
         cnicFront, cnicBack, profilePic, workCert, license, licenseBack,
         worker_form_completed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `;

      const values = [
        fullName,
        cnic,
        phone,
        city,
        skill,
        availableHours,
        about || null,

        files.cnicFront?.[0]?.buffer || null,
        files.cnicBack?.[0]?.buffer || null,
        files.profilePic?.[0]?.buffer || null,
        files.workCert?.[0]?.buffer || null,
        files.license?.[0]?.buffer || null,
        files.licenseBack?.[0]?.buffer || null,

        true,
      ];

      const [result] = await dbp.query(sql, values);

      res.json({
        success: true,
        workerId: result.insertId,
      });

    } catch (err) {
      console.error("❌ Worker insert error:", err);
      res.status(500).json({ error: "Failed to save worker" });
    }
  }
);

app.get("/api/worker/:id", async (req, res) => {
  try {
    const workerId = req.params.id;

    const [rows] = await dbp.query(
      "SELECT * FROM workers WHERE id = ?",
      [workerId]
    );

    if (rows.length === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    const worker = rows[0];

    // Convert images to Base64
    const toBase64 = (buffer) =>
      buffer ? buffer.toString("base64") : null;

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

// ================== Update/Upload single document for worker ==================
app.put(
  "/api/worker/:id/documents",
  upload.single("file"),
  async (req, res) => {
    const { id } = req.params;
    const { field } = req.query;
    const file = req.file; // This is the file from multer
    if (!field || !ALLOWED_FILE_FIELDS.includes(field)) {
      return res.status(400).json({
        error: `Invalid or missing 'field' query. Allowed: ${ALLOWED_FILE_FIELDS.join(", ")}`,
      });
    }

    if (!file) {
      return res.status(400).json({ error: "No file uploaded (use form field 'file')" });
    }

    try {
      // Use the file buffer directly, not a filename
      const fileBuffer = file.buffer;

      // Update the database with the new file buffer
      const sql = `UPDATE workers SET ${field} = ? WHERE id = ?`;
      const [result] = await dbp.query(sql, [fileBuffer, id]);

      if (result.affectedRows === 0) {
        return res.status(404).json({ error: "Worker not found" });
      }

      res.json({
        message: "Document updated successfully",
        field: field,
      });
    } catch (err) {
      console.error("❌ Error updating document:", err);
      res.status(500).json({ error: "Server error while updating document" });
    }
  }
);

// ================== Delete document for worker ==================
app.delete("/api/worker/:id/documents", async (req, res) => {
  const { id } = req.params;
  const { field } = req.query;

  if (!field || !ALLOWED_FILE_FIELDS.includes(field)) {
    return res.status(400).json({
      error: `Invalid or missing 'field' query. Allowed: ${ALLOWED_FILE_FIELDS.join(", ")}`,
    });
  }

  try {
    // Set the field to NULL in the database
    const sql = `UPDATE workers SET ${field} = NULL WHERE id = ?`;
    const [result] = await dbp.query(sql, [id]);

    if (result.affectedRows === 0) {
      return res.status(404).json({ error: "Worker not found" });
    }

    res.json({ message: "File deleted and DB updated successfully" });
  } catch (err) {
    console.error("❌ Error deleting document:", err);
    res.status(500).json({ error: "Server error" });
  }
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

