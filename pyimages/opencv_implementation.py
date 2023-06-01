import numpy as np
import cv2

def invert_cv2absdiff(img:np.ndarray)-> np.ndarray:
    return cv2.absdiff(img, 255)