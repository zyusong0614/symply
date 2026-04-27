from PIL import Image, ImageChops

def trim(im):
    bg = Image.new(im.mode, im.size, im.getpixel((0,0)))
    diff = ImageChops.difference(im, bg)
    diff = ImageChops.add(diff, diff, 2.0, -100)
    bbox = diff.getbbox()
    if bbox:
        return im.crop(bbox)
    return im

img = Image.open('AppIcon.png')
img = img.convert("RGBA")

# find background color
bg_color = img.getpixel((0, 0))

# make background transparent
datas = img.getdata()
newData = []
for item in datas:
    if item[0] >= 240 and item[1] >= 240 and item[2] >= 240: # roughly white
        newData.append((255, 255, 255, 0))
    else:
        newData.append(item)

img.putdata(newData)

# trim transparent edges
bbox = img.getbbox()
if bbox:
    img = img.crop(bbox)

# scale to 1024x1024
img = img.resize((1024, 1024), Image.LANCZOS)
img.save('AppIcon_cropped.png')
