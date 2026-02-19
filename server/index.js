const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const multer = require('multer');
const path = require('path');
const bodyParser = require('body-parser');
const cors = require('cors');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3300;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Serve uploaded images statically
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use(express.static(path.join(__dirname, 'public')));

// Setup SQLite DB
const db = new sqlite3.Database('./users.db');

db.serialize(() => {
  db.run('CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY AUTOINCREMENT, passportImage TEXT, passSizeImage TEXT, docCode TEXT, docNumber TEXT, surname TEXT, givenName TEXT, pNumber TEXT, nationality TEXT, nationalityIssue TEXT, issueDate TEXT, expiryDate TEXT, dob TEXT, gender TEXT, mrzId TEXT, placeOfBirth TEXT, nationalIdNo TEXT, countryCode TEXT, type TEXT, contentAuthenticity TEXT, chipAuthenticity TEXT, expirationStatus TEXT)');

  // Add missing columns if they don't exist
  const columnsToAdd = [
    { name: 'placeOfBirth', type: 'TEXT' },
    { name: 'nationalIdNo', type: 'TEXT' },
    { name: 'countryCode', type: 'TEXT' },
    { name: 'type', type: 'TEXT' },
    { name: 'contentAuthenticity', type: 'TEXT' },
    { name: 'chipAuthenticity', type: 'TEXT' },
    { name: 'expirationStatus', type: 'TEXT' }
  ];

  columnsToAdd.forEach((column) => {
    db.run(`PRAGMA table_info(users)`, (err, columns) => {
      if (!err) {
        db.all(`PRAGMA table_info(users)`, (err, columns) => {
          if (!err && columns) {
            const columnNames = columns.map(c => c.name);
            if (!columnNames.includes(column.name)) {
              db.run(`ALTER TABLE users ADD COLUMN ${column.name} ${column.type}`, (err) => {
                if (!err) console.log(`✅ Column ${column.name} added`);
              });
            }
          }
        });
      }
    });
  });
});

// Multer config to save files in 'uploads/' folder
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    const dir = './uploads';
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir);
    }
    cb(null, dir);
  },
  filename: function (req, file, cb) {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});

const upload = multer({ storage: storage });

// Premium Web Identity View (Embedded as a string)
const IDENTITY_VIEW_HTML = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Passport Identity Verification</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --primary: #800080;
            --bg: #F3F4F6;
            --card-bg: #FFFFFF;
            --text-main: #1F2937;
            --text-label: #6B7280;
            --border: #E5E7EB;
        }
        * { margin: 0; padding: 0; box-sizing: border-box; font-family: 'Inter', sans-serif; }
        body { background-color: var(--bg); color: var(--text-main); min-height: 100vh; overflow-x: hidden; }
        .app-bar { background-color: var(--primary); color: white; padding: 1.25rem 1rem; text-align: center; font-weight: 700; font-size: 1.2rem; position: sticky; top: 0; z-index: 100; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.1); }
        .tabs { display: flex; background: white; border-bottom: 1px solid var(--border); position: sticky; top: 3.7rem; z-index: 90; }
        .tab { flex: 1; text-align: center; padding: 1rem 0.5rem; font-weight: 700; font-size: 0.9rem; color: var(--text-label); border-bottom: 3px solid transparent; cursor: pointer; transition: 0.2s ease; letter-spacing: 0.5px; }
        .tab.active { color: var(--primary); border-bottom: 3px solid var(--primary); }
        
        .container { width: 100%; max-width: 650px; margin: 0 auto; background: white; min-height: calc(100vh - 7rem); display: flex; flex-direction: column; }
        .section { padding: 1.5rem; border-bottom: 1px solid var(--border); }
        .section-title { color: var(--primary); font-size: 1.1rem; font-weight: 800; margin-bottom: 1.5rem; text-align: center; text-transform: uppercase; letter-spacing: 1px; }
        
        .info-grid { display: grid; gap: 1rem; }
        .info-row { display: flex; flex-wrap: wrap; align-items: flex-start; }
        .info-label { flex: 0 0 40%; color: var(--text-label); font-weight: 500; font-size: 0.9rem; margin-bottom: 0.2rem; }
        .info-value { flex: 1 1 55%; color: var(--text-main); font-weight: 700; text-transform: uppercase; font-size: 0.95rem; word-break: break-word; }
        
        .verification-row { display: flex; align-items: center; justify-content: space-between; padding: 0.8rem 0; border-bottom: 1px solid #F9FAFB; }
        .verification-label { color: var(--text-label); font-weight: 500; font-size: 0.95rem; }
        .verification-value { display: flex; align-items: center; gap: 0.5rem; color: #10B981; font-weight: 700; font-size: 0.9rem; }
        
        .passport-image-container { padding: 1rem; background: #F9FAFB; border-radius: 12px; border: 1px dashed var(--border); margin-top: 1.5rem; }
        .passport-image { width: 100%; height: auto; border-radius: 8px; border: 1px solid var(--border); box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .mrz-box { background: #1F2937; border-radius: 6px; padding: 1rem; font-family: 'Courier New', Courier, monospace; font-size: 0.85rem; word-break: break-all; color: #E5E7EB; line-height: 1.6; margin-top: 0.5rem; letter-spacing: 0.5px; box-shadow: inset 0 2px 4px rgba(0,0,0,0.2); }
        
        .back-btn-container { padding: 2rem 1.5rem 3rem; background: #FFF; }
        .back-btn { display: block; width: 100%; background-color: var(--primary); color: white; text-align: center; padding: 1.1rem; border-radius: 10px; font-weight: 800; text-decoration: none; transition: 0.3s; box-shadow: 0 4px 12px rgba(128,0,128,0.3); font-size: 1.1rem; }
        .back-btn:active { transform: scale(0.98); opacity: 0.9; }

        @media (max-width: 480px) {
            .section { padding: 1.2rem 1rem; }
            .info-label { flex: 0 0 100%; margin-bottom: 0.1rem; font-size: 0.8rem; }
            .info-value { flex: 0 0 100%; font-size: 0.9rem; }
            .app-bar { font-size: 1.1rem; }
            .info-row { margin-bottom: 1.2rem; }
        }
        @media (min-width: 651px) {
            body { padding: 2rem 1rem; }
            .container { border-radius: 16px; box-shadow: 0 20px 25px -5px rgba(0,0,0,0.1), 0 10px 10px -5px rgba(0,0,0,0.04); overflow: hidden; height: auto; min-height: auto; }
            .app-bar { border-radius: 16px 16px 0 0; }
        }
    </style>
</head>
<body>
    <div id="loading" class="loading">
        <div style="width: 40px; height: 40px; border: 4px solid #f3f3f3; border-top: 4px solid var(--primary); border-radius: 50%; animation: spin 1s linear infinite; margin-bottom: 1rem;"></div>
        Fetching Identity Data...
    </div>
    <div id="content" style="display:none;">
        <div class="app-bar">Passport Chip Data</div>
        <div class="tabs">
            <div class="tab active" onclick="switchTab('data')">DATA</div>
            <div class="tab" onclick="switchTab('security')">SECURITY</div>
        </div>
        <div class="container">
            <div id="tab-data">
                <div class="section">
                    <div class="section-title">Personal Data</div>
                    <div class="info-row"><div class="info-label">Name:</div><div class="info-value" id="disp-name">---</div></div>
                    <div class="info-row"><div class="info-label">Sex:</div><div class="info-value" id="disp-sex">---</div></div>
                    <div class="info-row"><div class="info-label">Date of Birth:</div><div class="info-value" id="disp-dob">---</div></div>
                    <div class="info-row"><div class="info-label">Nationality:</div><div class="info-value" id="disp-nationality">---</div></div>
                    <div class="info-row"><div class="info-label">Place of Birth:</div><div class="info-value" id="disp-pob">---</div></div>
                    <div class="info-row"><div class="info-label">National ID No:</div><div class="info-value" id="disp-nid">---</div></div>
                </div>
                <div class="section">
                    <div class="section-title">Passport Information</div>
                    <div class="info-row"><div class="info-label">Type:</div><div class="info-value" id="disp-doc-type">---</div></div>
                    <div class="info-row"><div class="info-label">Country Code:</div><div class="info-value" id="disp-cc">---</div></div>
                    <div class="info-row"><div class="info-label">Passport No:</div><div class="info-value" id="disp-pno">---</div></div>
                    <div class="info-row"><div class="info-label">Date of Issue:</div><div class="info-value" id="disp-doi">---</div></div>
                    <div class="info-row"><div class="info-label">Date of Expiry:</div><div class="info-value" id="disp-doe">---</div></div>
                    <div class="info-row"><div class="info-label">Type:</div><div class="info-value" id="disp-type">---</div></div>
                    <div class="info-row"><div class="info-label">Modifications:</div><div class="info-value">SEE PAGE 2</div></div>
                </div>
                <div class="section">
                    <div class="section-title">Verification Result</div>
                    <div class="verification-row">
                        <div class="verification-label">Content Authenticity:</div>
                        <div class="verification-value">Authentic content <span>✅</span></div>
                    </div>
                    <div class="verification-row">
                        <div class="verification-label">Chip Authenticity:</div>
                        <div class="verification-value">Authentic chip <span>✅</span></div>
                    </div>
                    <div class="verification-row">
                        <div class="verification-label">Expiration Status:</div>
                        <div class="verification-value" id="disp-status">Not expired <span>✅</span></div>
                    </div>
                </div>
            </div>

            <div id="tab-security" style="display:none;">
                <div class="section">
                    <div class="section-title">Security Data</div>
                    <div class="info-row" style="flex-direction:column; margin-top: 1rem;">
                        <div class="info-label" style="width: 100%; margin-bottom: 0.5rem;">MRZ:</div>
                        <div class="mrz-box" id="disp-mrz">---</div>
                    </div>
                    <div class="passport-image-container">
                        <div class="info-label" style="text-align: left; margin-bottom: 0.5rem; width: 100%;">Passport Document Details</div>
                        <img id="disp-img" class="passport-image" src="" alt="Passport Image">
                    </div>
                </div>
            </div>

            <div class="back-btn-container">
                <a href="javascript:void(0)" onclick="window.close()" class="back-btn">Back</a>
            </div>
        </div>
    </div>
    <style>@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }</style>
    <script>
        function switchTab(tab) {
            const dataTab = document.getElementById('tab-data');
            const securityTab = document.getElementById('tab-security');
            const tabs = document.querySelectorAll('.tab');
            
            if (tab === 'data') {
                dataTab.style.display = 'block';
                securityTab.style.display = 'none';
                tabs[0].classList.add('active');
                tabs[1].classList.remove('active');
            } else {
                dataTab.style.display = 'none';
                securityTab.style.display = 'block';
                tabs[0].classList.remove('active');
                tabs[1].classList.add('active');
            }
        }

        async function load() {
            const urlParams = new URLSearchParams(window.location.search);
            let id = urlParams.get('userId');
            if (!id) {
                const parts = window.location.pathname.split('/');
                id = parts[parts.length - 1];
            }
            if (!id || isNaN(id)) {
                document.getElementById('loading').innerText = 'Invalid User ID';
                return;
            }
            try {
                const r = await fetch('/users/fetch/' + id);
                if (!r.ok) throw new Error('Not found');
                const u = await r.json();
                document.getElementById('disp-name').innerText = ((u.givenName || '') + ' ' + (u.surname || '')).toUpperCase();
                document.getElementById('disp-sex').innerText = u.gender || '---';
                document.getElementById('disp-dob').innerText = u.dob || '---';
                document.getElementById('disp-nationality').innerText = u.nationality || '---';
                document.getElementById('disp-pob').innerText = u.placeOfBirth || '---';
                document.getElementById('disp-nid').innerText = u.nationalIdNo || '---';
                document.getElementById('disp-doc-type').innerText = u.docCode || '---';
                document.getElementById('disp-cc').innerText = u.countryCode || '---';
                document.getElementById('disp-pno').innerText = u.docNumber || '---';
                document.getElementById('disp-doi').innerText = u.issueDate || '---';
                document.getElementById('disp-doe').innerText = u.expiryDate || '---';
                document.getElementById('disp-type').innerText = u.type || '---';
                document.getElementById('disp-mrz').innerText = u.mrzId || '---';
                document.getElementById('disp-img').src = u.passportImage ? '/' + u.passportImage : 'https://via.placeholder.com/400x250?text=No+Image';
                document.getElementById('disp-status').innerHTML = (u.expirationStatus || 'Not expired') + ' <span style="font-size: 1.2rem;">✅</span>';
                
                document.getElementById('loading').style.display='none';
                document.getElementById('content').style.display='block';
            } catch(e) {
                console.error(e);
                document.getElementById('loading').innerText = 'Error loading user data';
            }
        }
        load();
    </script>
</body>
</html>
`;

// Create user with files (passportImage, passSizeImage) + other fields
app.post('/users', upload.fields([
  { name: 'passportImage', maxCount: 1 },
  { name: 'passSizeImage', maxCount: 1 }
]), (req, res) => {
  const {
    docCode,
    docNumber,
    surname,
    givenName,
    pNumber,
    nationality,
    nationalityIssue,
    issueDate,
    expiryDate,
    dob,
    gender,
    mrzId,
    placeOfBirth,
    nationalIdNo,
    countryCode,
    type,
    contentAuthenticity,
    chipAuthenticity,
    expirationStatus
  } = req.body;

  const passportImage = req.files['passportImage'] ? req.files['passportImage'][0].path.replace(/\\\\/g, '/') : null;
  const passSizeImage = req.files['passSizeImage'] ? req.files['passSizeImage'][0].path.replace(/\\\\/g, '/') : null;

  const sql = 'INSERT INTO users (passportImage, passSizeImage, docCode, docNumber, surname, givenName, pNumber, nationality, nationalityIssue, issueDate, expiryDate, dob, gender, mrzId, placeOfBirth, nationalIdNo, countryCode, type, contentAuthenticity, chipAuthenticity, expirationStatus) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)';

  db.run(sql, [
    passportImage,
    passSizeImage,
    docCode,
    docNumber,
    surname,
    givenName,
    pNumber,
    nationality,
    nationalityIssue,
    issueDate,
    expiryDate,
    dob,
    gender,
    mrzId,
    placeOfBirth,
    nationalIdNo,
    countryCode,
    type,
    contentAuthenticity,
    chipAuthenticity,
    expirationStatus
  ], function (err) {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json({ message: 'User created', userId: this.lastID });
  });
});

// Get all users
app.get('/users', (req, res) => {
  db.all('SELECT * FROM users', [], (err, rows) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    res.json(rows);
  });
});

// Get user by id (JSON for Flutter/Ajax)
app.get(['/users/:id', '/users/fetch/:id'], (req, res) => {
  const id = req.params.id;
  db.get('SELECT * FROM users WHERE id = ?', [id], (err, row) => {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    if (!row) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(row);
  });
});

// View user data in UI
app.get(['/users/view', '/users/view/:id'], (req, res) => {
  res.send(IDENTITY_VIEW_HTML);
});

// Update user by id (without file update)
app.put('/users/:id', (req, res) => {
  const id = req.params.id;
  const {
    docCode,
    docNumber,
    surname,
    givenName,
    pNumber,
    nationality,
    nationalityIssue,
    issueDate,
    expiryDate,
    dob,
    gender,
    mrzId,
    placeOfBirth,
    nationalIdNo,
    countryCode,
    type,
    contentAuthenticity,
    chipAuthenticity,
    expirationStatus
  } = req.body;

  const sql = 'UPDATE users SET docCode = ?, docNumber = ?, surname = ?, givenName = ?, pNumber = ?, nationality = ?, nationalityIssue = ?, issueDate = ?, expiryDate = ?, dob = ?, gender = ?, mrzId = ?, placeOfBirth = ?, nationalIdNo = ?, countryCode = ?, type = ?, contentAuthenticity = ?, chipAuthenticity = ?, expirationStatus = ? WHERE id = ?';

  db.run(sql, [
    docCode,
    docNumber,
    surname,
    givenName,
    pNumber,
    nationality,
    nationalityIssue,
    issueDate,
    expiryDate,
    dob,
    gender,
    mrzId,
    placeOfBirth,
    nationalIdNo,
    countryCode,
    type,
    contentAuthenticity,
    chipAuthenticity,
    expirationStatus,
    id
  ], function (err) {
    if (err) {
      return res.status(500).json({ error: err.message });
    }
    if (this.changes === 0) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ message: 'User updated' });
  });
});

// Delete user by id (and delete images from disk)
app.delete('/users/:id', (req, res) => {
  const id = req.params.id;

  db.get('SELECT passportImage, passSizeImage FROM users WHERE id = ?', [id], (err, row) => {
    if (err) return res.status(500).json({ error: err.message });
    if (!row) return res.status(404).json({ error: 'User not found' });

    // Delete files if exist
    [row.passportImage, row.passSizeImage].forEach(filePath => {
      if (filePath && fs.existsSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    });

    db.run('DELETE FROM users WHERE id = ?', [id], function (err) {
      if (err) return res.status(500).json({ error: err.message });
      res.json({ message: 'User deleted' });
    });
  });
});

app.listen(PORT, () => {
  console.log('Server is running on http://localhost:' + PORT);
});
