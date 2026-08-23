# 🚀 WeatherGPT Backend — Render.com 24/7 Deployment Guide

## 📋 Prerequisites
- A free [Render.com](https://render.com) account.
- Your project pushed to a GitHub repository.

---

## ⚡ Step 1: Deploy on Render (1-Click Blueprint or Web Service)

### Method A: Connect via Web Service (Recommended)
1. Go to [Render Dashboard](https://dashboard.render.com) and click **"New +"** ➔ **"Web Service"**.
2. Connect your GitHub repository (`WeatherGPT`).
3. Fill in the following details:
   - **Name**: `weathergpt-backend`
   - **Region**: `Singapore` (or closest to you)
   - **Branch**: `main`
   - **Root Directory**: `backend`
   - **Runtime**: `Python 3` (or `Docker`)
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - **Health Check Path**: `/health`

4. Add **Environment Variables** under the "Environment" tab:
   | Key | Value |
   |---|---|
   | `DATABASE_URL` | `postgresql+asyncpg://postgres:Kragsoft%40alec@db.psupzmalbgplbqfctpzg.supabase.co:5432/postgres` |
   | `SUPABASE_URL` | `https://psupzmalbgplbqfctpzg.supabase.co` |
   | `SUPABASE_KEY` | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzdXB6bWFsYmdwbGJxZmN0cHpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0OTY0OTAsImV4cCI6MjEwMzA3MjQ5MH0.3A6cbj-yM7GK6ngTZK5FNkTuod8Nnwwjyh_G9jTx6ik` |
   | `GEMINI_API_KEY` | `AQ.Ab8RN6JJlsEBIr_V9uLMvwOajg25-gIINBdpa9gsTcT2BLPg5Q` |
   | `SARVAM_API_KEY` | `sk_lxj60m2x_cwbQIgDmH6jULDCaZ87VXZQf` |
   | `PROJECT_NAME` | `WeatherGPT Backend` |
   | `API_V1_STR` | `/api/v1` |
   | `DEBUG` | `false` |

5. Click **"Create Web Service"**.
   - Your backend will deploy in ~2 minutes and give you a public HTTPS URL (e.g. `https://weathergpt-backend.onrender.com`).

---

## ⏰ Step 2: Keep Render 24/7 Alive (Prevent Free-Tier Sleep)

Render free tier goes to sleep after 15 minutes of idle time. To keep it **100% online 24/7**:

1. Go to [UptimeRobot.com](https://uptimerobot.com) (Free Account) or [Cron-Job.org](https://cron-job.org).
2. Click **"Add New Monitor"**:
   - **Monitor Type**: `HTTP(s)`
   - **Friendly Name**: `WeatherGPT 24/7 KeepAlive`
   - **URL / IP**: `https://weathergpt-backend.onrender.com/health` (Replace with your Render URL)
   - **Monitoring Interval**: `Every 5 minutes` (or `10 minutes`)
3. Click **"Create Monitor"**.

🎉 **UptimeRobot will ping your `/health` endpoint every 5 minutes, keeping Render awake 24/7 with zero downtime!**
