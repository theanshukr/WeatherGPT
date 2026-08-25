import asyncio
import os
import asyncpg
import requests

async def setup_test_user():
    database_url = os.getenv(
        "DATABASE_URL", 
        "postgresql://postgres:postgres@localhost:5432/weathergpt"
    )
    db_uri = database_url.replace("postgresql+asyncpg://", "postgresql://")
    
    print("Connecting to database for test user setup...")
    try:
        conn = await asyncpg.connect(db_uri, statement_cache_size=0)
        
        # Update password for test@weathergpt.com
        test_email = os.getenv("TEST_USER_EMAIL", "test@weathergpt.com")
        test_password = os.getenv("TEST_USER_PASSWORD", "WeatherTest@2026")
        
        await conn.execute("""
            UPDATE auth.users
            SET 
                encrypted_password = extensions.crypt($2, extensions.gen_salt('bf')),
                email_confirmed_at = NOW(),
                raw_app_meta_data = '{"provider": "email", "providers": ["email"]}',
                raw_user_meta_data = '{"full_name": "Test User", "persona": "farmer", "preferred_language": "en"}'
            WHERE email = $1;
        """, test_email, test_password)
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

        # Supabase API verification
        supabase_url = os.getenv("SUPABASE_URL", "https://your-supabase-project.supabase.co")
        supabase_key = os.getenv("SUPABASE_KEY", "")
        
        if supabase_key and "your-supabase-project" not in supabase_url:
            url = f"{supabase_url}/auth/v1/token?grant_type=password"
            headers = {
                'apikey': supabase_key,
                'Content-Type': 'application/json'
            }
            res = requests.post(url, headers=headers, json={'email': test_email, 'password': test_password})
            print(f"Supabase login test: status={res.status_code}")
            if res.status_code == 200:
                data = res.json()
                print(f"SUCCESS! Logged in as: {data.get('user', {}).get('email')}")
            else:
                print(f"Failed response: {res.text}")
    except Exception as e:
        print(f"Test user setup process encountered error: {e}")

if __name__ == "__main__":
    asyncio.run(setup_test_user())
