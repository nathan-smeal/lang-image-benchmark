import numpy as np
from math import sqrt

def invert_naive(img:np.ndarray)->np.ndarray:
    res = img.copy()
    for i in range(img.shape[0]):
        for j in range(img.shape[1]):
            for k in range(img.shape[2]):
                res[i][j][k] = abs(res[i][j][k] - 255)
    return res

def naive_sobel(img: np.ndarray) -> np.ndarray:
    res = img.copy()
    # not we are not buffering the border for simplicity

    kernel_x = [[-1, 0, 1],
                [-2, 0, 2],
                [-1, 0, 1]]
    kernel_y = [[-1, -2, -1],
                [0,0,0],
                [1,2,1]]
    for i in range(1,img.shape[0] -1):
        for j in range(1, img.shape[1]-1):
            pass

    return res
