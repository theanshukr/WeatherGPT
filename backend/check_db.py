import asyncio
import asyncpg

async def check_schema():
    conn = await asyncpg.connect(
        user='postgres.psupzmalbgplbqfctpzg',
        password='Kragsoft@alec',
        database='postgres',
        host='aws-0-ap-southeast-1.pooler.supabase.com',
        port=6543,
        statement_cache_size=0
    )
    
    cols = await conn.fetch("""
        SELECT column_name, data_type, is_nullable, column_default 
        FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = 'users';
    """)
    print("Columns of public.users:")
    for c in cols:
        print(dict(c))
        
    await conn.close()

if __name__ == "__main__":
    asyncio.run(check_schema())
