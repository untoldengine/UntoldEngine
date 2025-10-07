# compare_psnr.py

from skimage.metrics import peak_signal_noise_ratio
import cv2
import sys

def main():
    ref_path = sys.argv[1]
    test_path = sys.argv[2]

    ref = cv2.imread(ref_path, 0)
    test = cv2.imread(test_path, 0)

    psnr = peak_signal_noise_ratio(ref, test)
    print(psnr)  # You’ll capture this in Swift

    # Exit with error if PSNR is too low
    if psnr < 30:
        sys.exit(1)
    else:
        sys.exit(0)

if __name__ == "__main__":
    main()
