CXX = g++
CXXFLAGS = -O2 -Wall -Wextra
TARGET = cpp_bench

STB_DIR = stb
STB_IMAGE = $(STB_DIR)/stb_image.h
STB_IMAGE_WRITE = $(STB_DIR)/stb_image_write.h

STB_URL_BASE = https://raw.githubusercontent.com/nothings/stb/master

.PHONY: all clean

all: $(TARGET)

$(STB_DIR):
	mkdir -p $(STB_DIR)

$(STB_IMAGE): | $(STB_DIR)
	curl -sL $(STB_URL_BASE)/stb_image.h -o $@

$(STB_IMAGE_WRITE): | $(STB_DIR)
	curl -sL $(STB_URL_BASE)/stb_image_write.h -o $@

$(TARGET): main.cpp $(STB_IMAGE) $(STB_IMAGE_WRITE)
	$(CXX) $(CXXFLAGS) -I$(STB_DIR) -o $@ main.cpp -lm

clean:
	rm -f $(TARGET)
	rm -rf $(STB_DIR)
