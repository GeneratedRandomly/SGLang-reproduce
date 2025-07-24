import openai

client = openai.Client(base_url=f"http://localhost:8000/v1", api_key="None")

response = client.chat.completions.create(
    model="/ssd/DeepSeek-R1",
    messages=[
        {"role": "user", "content": "宫保鸡丁怎么做?"},
    ],
    temperature=0,
    max_tokens=10,
)
print(response)