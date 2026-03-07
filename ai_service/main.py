from fastapi import FastAPI, File, UploadFile
import easyocr
import re
import io
from PIL import Image
import numpy as np
from pydantic import BaseModel

app = FastAPI()

# Initialize the OCR reader (load it once to save time)
# 'en' is sufficient for CNIC numbers and English names
reader = easyocr.Reader(['en'])

def extract_cnic_info(text_list):
    data = {"cnic": "", "name": "", "dob": ""}

    # 1. Regex for CNIC Pattern (e.g., 12345-1234567-1)
    cnic_pattern = re.compile(r'\b\d{5}-\d{7}-\d{1}\b')

    # 2. Regex for Date of Birth (e.g., 12.03.1995 or 12/03/1995)
    dob_pattern = re.compile(r'\b\d{2}[\./-]\d{2}[\./-]\d{4}\b')

    for i, text in enumerate(text_list):
        # clean up the text
        clean_text = text.strip()

        # Check for CNIC Number
        if cnic_pattern.search(clean_text):
            data["cnic"] = cnic_pattern.search(clean_text).group()

        # Check for Date of Birth
        if dob_pattern.search(clean_text):
            # Try to avoid picking up the card issuance date (usually similar format)
            # A simple heuristic: DOB usually comes before expiry/issue dates in the list
            if not data["dob"]:
                data["dob"] = dob_pattern.search(clean_text).group()

        # Check for Name
        # Logic: If the current text is "Name" or "Father Name", the ACTUAL name
        # is usually the NEXT element in the list.
        if "Name" in clean_text and "Father" not in clean_text:
            if i + 1 < len(text_list):
                # This grabs the text immediately following the word "Name"
                data["name"] = text_list[i+1]

    return data

@app.post("/extract-cnic")
async def extract_cnic(file: UploadFile = File(...)):
    # 1. Read the image file
    image_data = await file.read()
    image = Image.open(io.BytesIO(image_data))

    # 2. Convert to numpy array for EasyOCR
    image_np = np.array(image)

    # 3. Perform OCR
    # detail=0 returns just the list of text strings
    results = reader.readtext(image_np, detail=0)

    # 4. Extract specific fields
    extracted_data = extract_cnic_info(results)

    return {"success": True, "data": extracted_data}

# To run this: uvicorn main:app --reload

# Yeh model define karta hai ke Flutter se data kis shakal mein aayega
class VoiceInput(BaseModel):
    text: str

@app.post("/process-voice-text")
async def process_voice_text(data: VoiceInput):
    text = data.text.lower()

    # Empty JSON ready karna
    extracted_data = {
        "city": "",
        "skill": "",
        "duration": ""
    }

    # 1. SMART SKILL EXTRACTION
    if any(word in text for word in ['electrician', 'bijli', 'tar', 'current']):
        extracted_data["skill"] = "Electrician"
    elif any(word in text for word in ['plumber', 'nal', 'pipe', 'pani', 'tanki']):
        extracted_data["skill"] = "Plumber"
    elif any(word in text for word in ['carpenter', 'lakri', 'furniture', 'darwaza']):
        extracted_data["skill"] = "Carpenter"
    elif any(word in text for word in ['painter', 'rang', 'paint', 'safedi']):
        extracted_data["skill"] = "Painter"

    # 2. SMART CITY EXTRACTION
    if any(word in text for word in ['lahore']):
        extracted_data["city"] = "Lahore"
    elif any(word in text for word in ['karachi']):
        extracted_data["city"] = "Karachi"
    elif any(word in text for word in ['islamabad']):
        extracted_data["city"] = "Islamabad"
    elif any(word in text for word in ['rawalpindi', 'pindi']):
        extracted_data["city"] = "Rawalpindi"

    # 3. SMART DURATION EXTRACTION
    if any(word in text for word in ['full', 'sara', 'din', 'poora']):
        extracted_data["duration"] = "Full Day"
    elif any(word in text for word in ['1', '3', 'aik', 'teen', 'ghante', 'thori']):
        extracted_data["duration"] = "1-3 Hours"
    elif any(word in text for word in ['4', '6', 'char', 'chhe', 'aadha']):
        extracted_data["duration"] = "4-6 Hours"

    print(f"User said: {text}")
    print(f"AI Extracted: {extracted_data}")

    return {
        "success": True,
        "data": extracted_data
    }