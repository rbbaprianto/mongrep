# HRM Labs MongoDB Replication Automation

Script automation lengkap untuk setup MongoDB cluster dengan web dashboard profesional untuk HR Management System.

## 🚀 Fitur Utama

- **Instalasi Otomatis MongoDB** di Rocky Linux 9
- **Konfigurasi Replication Cluster** dengan 3 node
- **Generate Dummy Data HR** lengkap dengan file media
- **Web Dashboard Modern** dengan fitur real-time monitoring
- **Live Replication Status** visual dengan grafik
- **Log Monitoring** real-time dari setiap node
- **Query Interface** untuk MongoDB langsung dari web
- **SSH Console** terintegrasi untuk setiap node
- **Configuration Management** dengan accounts.json

## 📋 Prasyarat

1. **Sistem Operasi**: Rocky Linux 9
2. **Akses Root**: Script harus dijalankan sebagai root
3. **SSH Access**: Koneksi SSH tanpa password ke semua node
4. **Node Names**: Pastikan hostname sudah dikonfigurasi:
   - `hrmlabs-mongo-primary`
   - `hrmlabs-mongo-secondary`
   - `hrmlabs-mongo-analytics`

## 🔧 Instalasi & Penggunaan

### 1. Download Script

```bash
# Download atau clone script
wget https://raw.githubusercontent.com/your-repo/hrmlabs-mongo-automation.sh
chmod +x hrmlabs-mongo-automation.sh
```

### 2. Setup SSH Keys (Opsional)

```bash
# Generate SSH key jika belum ada
ssh-keygen -t rsa -b 4096 -C "hrmlabs-automation"

# Copy public key ke semua node
ssh-copy-id root@hrmlabs-mongo-primary
ssh-copy-id root@hrmlabs-mongo-secondary
ssh-copy-id root@hrmlabs-mongo-analytics
```

### 3. Jalankan Script

```bash
# Jalankan sebagai root
sudo ./hrmlabs-mongo-automation.sh
```

Script akan otomatis melakukan:
1. ✅ Install dependencies lokal
2. ✅ Cek konektivitas SSH ke semua node
3. ✅ Install MongoDB di setiap node (jika belum ada)
4. ✅ Konfigurasi replication cluster
5. ✅ Generate dan insert dummy data HR
6. ✅ Setup web dashboard
7. ✅ Validasi semua komponen

## 📊 Data HR yang Dihasilkan

Script akan menghasilkan data lengkap untuk HR Management:

- **5 Perusahaan** dengan informasi lengkap
- **100 Karyawan** dengan data personal
- **5 Departemen** (HR, IT, Finance, Marketing, Operations)
- **5 Posisi Jabatan** dengan range gaji
- **1,500+ Record Absensi** (30 hari terakhir)
- **50 Pengajuan Cuti** dengan berbagai status
- **1,200 Record Payroll** (12 bulan)
- **40+ File Dokumen** (foto karyawan, kontrak) dalam format PNG/JPG

## 🌐 Web Dashboard

Setelah instalasi selesai, akses dashboard di:
```
http://localhost:3000
```

### Fitur Dashboard:

#### 1. **Live Replication Status**
- Grafik visual status replica set
- Status health setiap node
- Informasi member replica set real-time

#### 2. **Log Monitoring**
- View log MongoDB dari setiap node
- Auto-refresh setiap 10 detik
- Filter berdasarkan node

#### 3. **Query Interface**
- Execute query MongoDB langsung dari web
- Support untuk semua node (primary/secondary/analytics)
- Syntax highlighting dan hasil formatted

#### 4. **SSH Console**
- Akses SSH ke setiap node dari browser
- Execute command real-time
- History command dan output

#### 5. **Configuration Management**
- Load/save konfigurasi node
- Manage accounts.json
- Export data functionality

## 🏗️ Arsitektur MongoDB Cluster

```
┌─────────────────────────────────────────────────────────────┐
│                    HRM Labs MongoDB Cluster                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────┐ │
│  │  PRIMARY NODE   │  │ SECONDARY NODE  │  │ANALYTICS NODE│ │
│  │                 │  │                 │  │              │ │
│  │ hrmlabs-mongo-  │◄─┤ hrmlabs-mongo-  │◄─┤hrmlabs-mongo-│ │
│  │ primary:27017   │  │ secondary:27017 │  │analytics:27017│ │
│  │                 │  │                 │  │              │ │
│  │ Priority: 2     │  │ Priority: 1     │  │Priority: 0   │ │
│  │ Votes: 1        │  │ Votes: 1        │  │Hidden: true  │ │
│  └─────────────────┘  └─────────────────┘  └──────────────┘ │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    Replica Set: hrmlabsrs                   │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Struktur File

```
/workspace/
├── hrmlabs-mongo-automation.sh     # Script utama
├── package.json                    # Dependencies Node.js
├── server.js                       # Web dashboard server
├── accounts.json                   # Konfigurasi node
├── dashboard.log                   # Log dashboard
├── generate_hr_data.py            # Script generate data (temporary)
└── public/
    └── index.html                 # Dashboard frontend
```

## 🔍 Monitoring & Troubleshooting

### Cek Status Replica Set
```bash
mongosh --host hrmlabs-mongo-primary:27017 --eval "rs.status()"
```

### View Dashboard Logs
```bash
tail -f /workspace/dashboard.log
```

### Restart Dashboard
```bash
cd /workspace
npm start
```

### Cek Koneksi Node
```bash
# Test SSH connectivity
ssh root@hrmlabs-mongo-primary "echo 'OK'"
ssh root@hrmlabs-mongo-secondary "echo 'OK'"
ssh root@hrmlabs-mongo-analytics "echo 'OK'"

# Test MongoDB connectivity
mongosh --host hrmlabs-mongo-primary:27017 --eval "db.runCommand('ping')"
```

## 🔒 Keamanan

⚠️ **PENTING**: Script ini dibuat untuk lingkungan development/testing. Untuk production:

1. **Aktifkan Authentication MongoDB**
2. **Setup SSL/TLS**
3. **Konfigurasi Firewall**
4. **Use Strong Passwords**
5. **Setup Backup Strategy**

## 📝 Contoh Query MongoDB

### Lihat Data Karyawan
```javascript
db.employees.find().limit(5).pretty()
```

### Statistik Absensi
```javascript
db.attendance.aggregate([
  {$group: {_id: "$status", count: {$sum: 1}}}
])
```

### Payroll Bulanan
```javascript
db.payroll.find({month: 12, year: 2024}).limit(10)
```

### Dokumen Karyawan
```javascript
db.documents.find({document_type: "photo"}).limit(3)
```

## 🐛 Troubleshooting

### MongoDB Service Error
```bash
# Restart MongoDB service pada node bermasalah
ssh root@hrmlabs-mongo-primary "systemctl restart mongod"
```

### Dashboard Tidak Accessible
```bash
# Check port 3000
netstat -tulpn | grep :3000

# Restart dashboard
cd /workspace && npm start
```

### SSH Connection Failed
```bash
# Test SSH connectivity
ssh -v root@hrmlabs-mongo-primary

# Check SSH service
ssh root@hrmlabs-mongo-primary "systemctl status sshd"
```

## 📞 Support

Untuk pertanyaan atau issue, silakan buat GitHub issue atau hubungi tim development.

---

**© 2024 HRM Labs - MongoDB Automation Script**