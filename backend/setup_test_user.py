import asyncio
import asyncpg
import requests

async def setup_test_user():
    conn = await asyncpg.connect(
        user='postgres.psupzmalbgplbqfctpzg',
        password='Kragsoft@alec',
        database='postgres',
        host='aws-0-ap-southeast-1.pooler.supabase.com',
        port=6543,
        statement_cache_size=0
    )
    
    # Update password for test@weathergpt.com to WeatherTest@2026
    await conn.execute("""
        UPDATE auth.users
        SET 
            encrypted_password = extensions.crypt('WeatherTest@2026', extensions.gen_salt('bf')),
            email_confirmed_at = NOW(),
            raw_app_meta_data = '{"provider": "email", "providers": ["email"]}',
            raw_user_meta_data = '{"full_name": "Test User", "persona": "farmer", "preferred_language": "en"}'
        WHERE email = 'test@weathergpt.com';
    """)
    print("Updated auth.users password and confirmation.")
    
    # Check or insert into public.users
    user_id = 'ba17e674-b060-4a99-8732-4e1b1d10d04a'
    await conn.execute("""
        INSERT INTO public.users (
            id, 
            preferred_language, 
            inferred_persona, 
            persona_confidence, 
            preferences, 
            saved_locations,
            created_at,
            updated_at
        ) VALUES (
            $1,
            'en',
            'farmer',
            0.95,
            '{"email": "test@weathergpt.com", "notifications": true, "temp_unit": "celsius"}'::json,
            '[{"name": "New Delhi", "lat": 28.6139, "lon": 77.2090, "is_primary": true}]'::json,
            NOW(),
            NOW()
        )
        ON CONFLICT (id) DO UPDATE SET
            preferred_language = EXCLUDED.preferred_language,
            inferred_persona = EXCLUDED.inferred_persona,
            preferences = EXCLUDED.preferences,
            saved_locations = EXCLUDED.saved_locations,
            updated_at = NOW();
    """, user_id)
    print("Inserted/Updated profile in public.users.")
    
    await conn.close()

    # Now verify login with Supabase API
    url = 'https://psupzmalbgplbqfctpzg.supabase.co/auth/v1/token?grant_type=password'
    headers = {
        'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBzdXB6bWFsYmdwbGJxZmN0cHpnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODc0OTY0OTAsImV4cCI6MjEwMzA3MjQ5MH0.3A6cbj-yM7GK6ngTZK5FNkTuod8Nnwwjyh_G9jTx6ik',
        'Content-Type': 'application/json'
    }
    res = requests.post(url, headers=headers, json={'email': 'test@weathergpt.com', 'password': 'WeatherTest@2026'})
    print(f"Supabase login test: status={res.status_code}")
    if res.status_code == 200:
        data = res.json()
        print(f"SUCCESS! Logged in as: {data.get('user', {}).get('email')}")
        print(f"User ID: {data.get('user', {}).get('id')}")
        print(f"Access Token: {data.get('access_token')[:25]}...")
    else:
        print(f"Failed response: {res.text}")

if __name__ == "__main__":
    asyncio.run(setup_test_user())
