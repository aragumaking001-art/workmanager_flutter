import os
from PIL import Image, ImageDraw, ImageFont

def draw_text_with_outline(draw, pos, text, font, fill_color, stroke_color, stroke_width, shadow_color=None, shadow_offset=(0,0)):
    x, y = pos
    if shadow_color and shadow_offset != (0, 0):
        sx, sy = shadow_offset
        for dx in range(-stroke_width, stroke_width + 1):
            for dy in range(-stroke_width, stroke_width + 1):
                draw.text((x + sx + dx, y + sy + dy), text, font=font, fill=shadow_color)
    for dx in range(-stroke_width, stroke_width + 1):
        for dy in range(-stroke_width, stroke_width + 1):
            draw.text((x + dx, y + dy), text, font=font, fill=stroke_color)
    draw.text((x, y), text, font=font, fill=fill_color)

def main():
    src_path = 'assets/wakeflix_joutou_16x9.jpg'
    base_img = Image.open(src_path).convert('RGBA')
    W, H = base_img.size # 1376, 768
    
    font_path = 'C:/Windows/Fonts/BIZ-UDGothicB.ttc'
    if not os.path.exists(font_path):
        font_path = 'C:/Windows/Fonts/meiryob.ttc'

    # ----------------------------------------------------
    # Variation A: Netflix Official Subtitle Style (Bottom-Center, above WAKEFLIX)
    # Authentic Netflix reality subtitle look: sleek dark pill, clean white text, crisp rendering
    # ----------------------------------------------------
    im_a = base_img.copy()
    overlay_a = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d_a = ImageDraw.Draw(overlay_a)
    
    font_a = ImageFont.truetype(font_path, 36)
    text_a = "「矢野はやべぇだろ」"
    bbox_a = d_a.textbbox((0, 0), text_a, font=font_a)
    tw_a = bbox_a[2] - bbox_a[0]
    th_a = bbox_a[3] - bbox_a[1]
    
    # Position: Centered horizontally, just above the WAKEFLIX logo (around y=615)
    cx = W // 2
    px = cx - tw_a // 2
    py = 620
    
    # Pill background
    pad_x, pad_y = 26, 10
    pill_box = [(px - pad_x, py - pad_y), (px + tw_a + pad_x, py + th_a + pad_y + 4)]
    d_a.rounded_rectangle(pill_box, radius=12, fill=(0, 0, 0, 190), outline=(255, 255, 255, 60), width=1)
    
    # White text with subtle shadow
    draw_text_with_outline(
        d_a, (px, py), text_a, font_a,
        fill_color=(255, 255, 255, 255),
        stroke_color=(20, 20, 20, 200),
        stroke_width=2,
        shadow_color=(0, 0, 0, 220),
        shadow_offset=(2, 2)
    )
    im_a = Image.alpha_composite(im_a, overlay_a)
    im_a.convert('RGB').save('scratch/yano_var_A_netflix_subtitle.jpg', quality=95)
    im_a.convert('RGB').save('C:/Users/user/Desktop/和気上等_矢野はやべぇだろ_A_Netflix字幕風.jpg', quality=95)
    print("Variation A saved.")

    # ----------------------------------------------------
    # Variation B: Reality TV Impact Telop (Floating near Baby & Spray Bottle)
    # Bright reality TV styling: Yellow text with white border and black shadow, dynamic pop
    # Positioned at center-right (x: 640 ~ 780, y: 340) next to the spray bottle & pink gal
    # ----------------------------------------------------
    im_b = base_img.copy()
    overlay_b = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d_b = ImageDraw.Draw(overlay_b)
    
    font_b = ImageFont.truetype(font_path, 42)
    text_b = "「矢野はやべぇだろ」"
    
    # Near Baby's spray bottle and the center rack space (x: 610, y: 340)
    draw_text_with_outline(
        d_b, (610, 340), text_b, font_b,
        fill_color=(255, 240, 0, 255),        # Variety Yellow
        stroke_color=(255, 255, 255, 255),    # White Stroke
        stroke_width=4,
        shadow_color=(0, 0, 0, 230),          # Bold Black Shadow
        shadow_offset=(4, 4)
    )
    im_b = Image.alpha_composite(im_b, overlay_b)
    im_b.convert('RGB').save('scratch/yano_var_B_baby_telop.jpg', quality=95)
    im_b.convert('RGB').save('C:/Users/user/Desktop/和気上等_矢野はやべぇだろ_B_テロップ風.jpg', quality=95)
    print("Variation B saved.")

    # ----------------------------------------------------
    # Variation C: Pink Neon Cyber / Sticker Badge (Angled Trailer Quote)
    # Styled like the Netflix trailer punchline stickers with hot-pink border matching 和気上等
    # Placed in the center background space (x: 580, y: 330)
    # ----------------------------------------------------
    im_c = base_img.copy()
    badge_w, badge_h = 490, 85
    badge = Image.new('RGBA', (badge_w, badge_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    
    bd.rounded_rectangle([(4, 4), (badge_w - 4, badge_h - 4)], radius=16, fill=(10, 15, 30, 225), outline=(255, 42, 133, 255), width=3)
    font_c = ImageFont.truetype(font_path, 34)
    text_c = "“ 矢野はやべぇだろ ”"
    bbox_c = bd.textbbox((0, 0), text_c, font=font_c)
    tw_c = bbox_c[2] - bbox_c[0]
    th_c = bbox_c[3] - bbox_c[1]
    tx_c = (badge_w - tw_c) // 2
    ty_c = (badge_h - th_c) // 2 - 3
    
    draw_text_with_outline(
        bd, (tx_c, ty_c), text_c, font_c,
        fill_color=(255, 255, 255, 255),
        stroke_color=(255, 42, 133, 220),
        stroke_width=2,
        shadow_color=(0, 0, 0, 200),
        shadow_offset=(2, 2)
    )
    # Angle slightly (-5 deg) for dynamic punch
    rot_badge = badge.rotate(5, expand=True, resample=Image.Resampling.BICUBIC)
    im_c.paste(rot_badge, (580, 335), rot_badge)
    im_c.convert('RGB').save('scratch/yano_var_C_neon_badge.jpg', quality=95)
    im_c.convert('RGB').save('C:/Users/user/Desktop/和気上等_矢野はやべぇだろ_C_ネオンバッジ.jpg', quality=95)
    print("Variation C saved.")

    # ----------------------------------------------------
    # Variation D: Speech Bubble from Baby (holding the spray bottle)
    # A chic speech bubble with pointer tail extending towards Baby
    # ----------------------------------------------------
    im_d = base_img.copy()
    bubble_w, bubble_h = 440, 80
    bubble = Image.new('RGBA', (bubble_w + 40, bubble_h + 30), (0, 0, 0, 0))
    bdd = ImageDraw.Draw(bubble)
    
    # Bubble body
    bdd.rounded_rectangle([(10, 10), (bubble_w, bubble_h)], radius=20, fill=(20, 22, 35, 230), outline=(255, 220, 50, 255), width=3)
    # Bubble tail pointing right towards Baby
    tail = [(bubble_w - 20, bubble_h - 10), (bubble_w + 30, bubble_h + 15), (bubble_w - 5, bubble_h - 30)]
    bdd.polygon(tail, fill=(20, 22, 35, 230), outline=(255, 220, 50, 255))
    # Redraw right border to merge
    bdd.line([(bubble_w - 20, bubble_h - 10), (bubble_w - 5, bubble_h - 30)], fill=(20, 22, 35, 255), width=4)
    
    font_d = ImageFont.truetype(font_path, 32)
    text_d = "「矢野はやべぇだろ」"
    bbox_d = bdd.textbbox((0, 0), text_d, font=font_d)
    tw_d = bbox_d[2] - bbox_d[0]
    th_d = bbox_d[3] - bbox_d[1]
    tx_d = (bubble_w - tw_d) // 2 + 5
    ty_d = (bubble_h - th_d) // 2 - 2
    
    draw_text_with_outline(
        bdd, (tx_d, ty_d), text_d, font_d,
        fill_color=(255, 240, 50, 255),
        stroke_color=(0, 0, 0, 240),
        stroke_width=2,
        shadow_color=(0, 0, 0, 180),
        shadow_offset=(2, 2)
    )
    im_d.paste(bubble, (530, 315), bubble)
    im_d.convert('RGB').save('scratch/yano_var_D_speech_bubble.jpg', quality=95)
    im_d.convert('RGB').save('C:/Users/user/Desktop/和気上等_矢野はやべぇだろ_D_吹き出し.jpg', quality=95)
    print("Variation D saved.")

if __name__ == '__main__':
    main()
