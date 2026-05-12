import base64
import numpy as np

embedding_base64 = """embled data here"""

# แปลง base64 -> bytes
binary_data = base64.b64decode(embedding_base64)
print(binary_data)
# แปลง bytes -> float64 array
embedding = np.frombuffer(binary_data, dtype=np.float64)
print(embedding)
print(len(embedding))
