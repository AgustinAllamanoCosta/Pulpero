if __name__ == "__main__":
    import sys
    from sentence_transformers import SentenceTransformer
    import json
    sentence_model = None
    vector = None
    try:
        sentence_model = SentenceTransformer('all-MiniLM-L6-v2')
        if len(sys.argv) > 1 :
            vector = model.encode(sys.argv[1])
            result = {
                "embedding": vector.tolist(),
                "dimensions": len(vector),
            }
            print(json.dumps(result))
        else:
            print("Nothing to encode, not argument was spicify")
    except Exception as e:
        error_result = {
            "error": e,
        }
        print(json.dumps(error_result))
