# -*- coding: utf-8 -*-
# https://youtu.be/16s3Pi1InPU
"""
Comparing images using ORB/SIFT feature detectors
and structural similarity index. 

@author: Sreenivas Bhattiprolu
"""


from skimage.metrics import structural_similarity
from skimage.metrics import peak_signal_noise_ratio
import cv2



#Needs images to be same dimensions
def structural_sim(img1, img2):

  sim, diff = structural_similarity(img1, img2, full=True)
  return sim

img00 = cv2.imread('/Users/haroldserrano/Downloads/UntoldEngineRenderingTest/ColorTargetReference.png', 0)
img01 = cv2.imread('/Users/haroldserrano/Downloads/UntoldEngineRenderingTest/ColorTargetTest.png', 0)


ssim = structural_sim(img00, img01) #1.0 means identical. Lower = not similar
print("Similarity using SSIM is: ", ssim)

psnr = peak_signal_noise_ratio(img00,img01)
print("PSNR", psnr)