import os
from PIL import Image, ImageDraw, ImageFont

def draw_text_with_outline(draw, pos, text, font, fill_color, stroke_color, stroke_width, shadow_color=None, shadow_offset=(0,0)):
    x, y = pos
    if shadow_color and shadow_offset != (0, 0):
        sx, sy = shadow_offset
        # draw shadow with stroke
        for dx in range(-stroke_width, stroke_width + 1):
            for dy in range(-stroke_width, stroke_width + 1):
                draw.text((x + sx + dx, y + sy + dy), text, font=font, fill=shadow_color)
    # draw main stroke
    for dx in range(-stroke_width, stroke_width + 1):
        for dy in range(-stroke_width, stroke_width + 1):
            draw.text((x + dx, y + dy), text, font=font, fill=stroke_color)
    # draw main text
    draw.text((x, y), text, font=font, fill=fill_color)

def main():
    src_path = 'assets/wakeflix_joutou_16x9.jpg'
    base_img = Image.open(src_path).convert('RGBA')
    font_path = 'C:/Windows/Fonts/BIZ-UDGothicB.ttc'
    if not os.path.exists(font_path):
        font_path = 'C:/Windows/Fonts/meiryob.ttc'

    # --- Pattern 1: Variety / Reality TV Subtitle (Yellow with white & black outline) on left side ---
    im1 = base_img.copy()
    overlay1 = Image.new('RGBA', im1.size, (0, 0, 0, 0))
    d1 = ImageDraw.Draw(overlay1)
    
    font_large = ImageFont.truetype(font_path, 46)
    text1 = "「矢野はやべぇだろ」"
    
    # Position: Upper-left between male technicians (x: 130, y: 310)
    # Slight shadow and intense yellow fill
    draw_text_with_outline(
        d1, (130, 310), text1, font_large,
        fill_color=(255, 240, 0, 255),       # Vibrant TV Yellow
        stroke_color=(255, 255, 255, 255),   # Crisp White inner outline
        stroke_width=4,
        shadow_color=(0, 0, 0, 220),         # Deep black drop shadow
        shadow_offset=(5, 5)
    )
    # Outer dark stroke
    im1 = Image.alpha_composite(im1, overlay1)
    out1_path = 'C:/Users/user/Desktop/和気上等_矢野はやべぇだろ_テロップ.jpg'
    im1.convert('RGB').save(out1_path, quality=95)
    print("Pattern 1 saved to:", out1_path)

    # --- Pattern 2: Viral Quote Badge (Angled Neon Pink / Yellow Sticker) ---
    im2 = base_img.copy()
    badge_w, badge_h = 520, 110
    badge = Image.new('RGBA', (badge_w, badge_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    
    # Rounded badge box
    bd.rounded_rectangle([(10, 10), (badge_w - 10, badge_h - 10)], radius=24, fill=(15, 20, 35, 210), outline=(255, 42, 133, 255), width=3)
    
    font_badge = ImageFont.truetype(font_path, 40)
    text_badge = "“ 矢野はやべぇだろ ”"
    # Center text inside badge
    bbox = bd.textbbox((0, 0), text_badge, font=font_badge)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (badge_w - tw) // 2
    ty = (badge_h - th) // 2 - 5
    draw_text_with_outline(
        bd, (tx, ty), text_badge, font_badge,
        fill_color=(255, 255, 255, 255),
        stroke_color=(255, 42, 133, 255),    # Hot Pink Stroke matching 和気上等
        stroke_width=2,
        shadow_color=(0, 0, 0, 180),
        shadow_offset=(3, 3)
    )
    
    # Rotate badge slightly (-6 degrees) for dramatic trailer effect
    rotated_badge = badge.rotate(6, expand=True, resample=Image.Resampling.BICUBIC)
    
    # Place near the center-left (x: 240, y: 390)
    im2.paste(rotated_badge, (230, 370), rotated_badge)
    out2_path = 'C:/Users/user/Desktop/和気上等_矢野はやべぇだろ_バッジ.jpg'
    im2.convert('RGB').save(out2_path, quality=95)
    print("Pattern 2 saved to:", out2_path)

if __name__ == '__main__':
    main()
