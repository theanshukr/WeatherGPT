import asyncio
import os
import asyncpg

async def check_schema():
    database_url = os.getenv(
        "DATABASE_URL", 
        "postgresql://postgres:postgres@localhost:5432/weathergpt"
    )
    # Strip +asyncpg for standard asyncpg connect if needed
    db_uri = database_url.replace("postgresql+asyncpg://", "postgresql://")
    
    print(f"Connecting to database...")
    try:
        conn = await asyncpg.connect(db_uri, statement_cache_size=0)
        cols = await conn.fetch("""
            SELECT column_name, data_type, is_nullable, column_default 
            FROM information_schema.columns 
            WHERE table_schema = 'public' AND table_name = 'users';
        """)
        print("Columns of public.users:")
        for c in cols:
            print(dict(c))
            
        await conn.close()
    except Exception as e:
        print(f"Connection failed: {e}")

if __name__ == "__main__":
    asyncio.run(check_schema())
