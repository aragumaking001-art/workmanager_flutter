import os
from PIL import Image, ImageDraw, ImageFont, ImageFilter

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
    # Candidate 1: バラエティ・ハイライトテロップ (金黄×白フチ×超立体ドロップシャドウ)
    # 中央の空間（ラック前、Babyの横）に配置。リアリティ番組の決定的一瞬のテロップ！
    # ----------------------------------------------------
    im1 = base_img.copy()
    overlay1 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d1 = ImageDraw.Draw(overlay1)
    
    font1 = ImageFont.truetype(font_path, 48)
    text1 = "「矢野はやべぇだろ」"
    bbox1 = d1.textbbox((0, 0), text1, font=font1)
    tw1 = bbox1[2] - bbox1[0]
    
    # x: 中央やや右寄りの空間 (x=550), y=340
    pos1 = (550, 345)
    
    # 3D shadow layers
    for s in range(6, 0, -1):
        draw_text_with_outline(
            d1, pos1, text1, font1,
            fill_color=(0, 0, 0, 200),
            stroke_color=(0, 0, 0, 200),
            stroke_width=4,
            shadow_offset=(s, s)
        )
    # White thick stroke
    draw_text_with_outline(
        d1, pos1, text1, font1,
        fill_color=(255, 235, 10, 255),       # Vivid Reality Yellow
        stroke_color=(255, 255, 255, 255),   # Thick White Outline
        stroke_width=5
    )
    im1 = Image.alpha_composite(im1, overlay1)
    im1.convert('RGB').save('scratch/yano_opt1_variety_telop.jpg', quality=95)
    im1.convert('RGB').save('C:/Users/user/Desktop/和気上等_1_バラエティテロップ風.jpg', quality=95)
    print("Candidate 1 saved.")

    # ----------------------------------------------------
    # Candidate 2: Netflix公式 字幕風 (下部中央・高透過ピル)
    # Netflixの配信画面そのもののリアルな字幕。洗練されたプロ感。
    # ----------------------------------------------------
    im2 = base_img.copy()
    overlay2 = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(overlay2)
    
    font2 = ImageFont.truetype(font_path, 34)
    text2 = "「矢野はやべぇだろ」"
    bbox2 = d2.textbbox((0, 0), text2, font=font2)
    tw2 = bbox2[2] - bbox2[0]
    th2 = bbox2[3] - bbox2[1]
    
    cx2 = W // 2
    px2 = cx2 - tw2 // 2
    py2 = 618
    
    # Sleek Netflix pill
    pad_x, pad_y = 28, 10
    d2.rounded_rectangle(
        [(px2 - pad_x, py2 - pad_y), (px2 + tw2 + pad_x, py2 + th2 + pad_y + 4)],
        radius=14,
        fill=(10, 10, 10, 210),
        outline=(255, 255, 255, 40),
        width=1
    )
    # Netflix white font with dark edge
    draw_text_with_outline(
        d2, (px2, py2), text2, font2,
        fill_color=(255, 255, 255, 255),
        stroke_color=(15, 15, 15, 220),
        stroke_width=2,
        shadow_color=(0, 0, 0, 240),
        shadow_offset=(2, 2)
    )
    im2 = Image.alpha_composite(im2, overlay2)
    im2.convert('RGB').save('scratch/yano_opt2_netflix_subtitle.jpg', quality=95)
    im2.convert('RGB').save('C:/Users/user/Desktop/和気上等_2_Netflix字幕風.jpg', quality=95)
    print("Candidate 2 saved.")

    # ----------------------------------------------------
    # Candidate 3: ネオンピンク・サイバー名言バッジ (ポスター一体型)
    # 『和気上等』のロゴと同じネオンピンクとサイバーダーク調で世界観に完全に溶け込むスタイル
    # ----------------------------------------------------
    im3 = base_img.copy()
    bw, bh = 460, 84
    badge = Image.new('RGBA', (bw, bh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(badge)
    
    # Outer neon glow simulation
    bd.rounded_rectangle([(3, 3), (bw - 3, bh - 3)], radius=18, fill=(15, 18, 32, 220), outline=(255, 42, 133, 255), width=3)
    
    font3 = ImageFont.truetype(font_path, 34)
    text3 = "“ 矢野はやべぇだろ ”"
    bbox3 = bd.textbbox((0, 0), text3, font=font3)
    tw3 = bbox3[2] - bbox3[0]
    th3 = bbox3[3] - bbox3[1]
    tx3 = (bw - tw3) // 2
    ty3 = (bh - th3) // 2 - 3
    
    draw_text_with_outline(
        bd, (tx3, ty3), text3, font3,
        fill_color=(255, 255, 255, 255),
        stroke_color=(255, 42, 133, 240),
        stroke_width=2,
        shadow_color=(0, 0, 0, 220),
        shadow_offset=(2, 2)
    )
    # Slight dynamic angle
    rot = badge.rotate(4, expand=True, resample=Image.Resampling.BICUBIC)
    im3.paste(rot, (560, 335), rot)
    im3.convert('RGB').save('scratch/yano_opt3_neon_badge.jpg', quality=95)
    im3.convert('RGB').save('C:/Users/user/Desktop/和気上等_3_ネオン名言バッジ風.jpg', quality=95)
    print("Candidate 3 saved.")

    # ----------------------------------------------------
    # Candidate 4: マンガ・劇画風インパクト吹き出し (Babyからの直撃セリフ)
    # スプレーを持ったBaby（ユリア風リーダー）の口元から出るアメコミ/ヤンキー風の吹き出し
    # ----------------------------------------------------
    im4 = base_img.copy()
    bw4, bh4 = 430, 86
    bubble = Image.new('RGBA', (bw4 + 50, bh4 + 40), (0, 0, 0, 0))
    bdd = ImageDraw.Draw(bubble)
    
    # Jagged/stylish quote box
    bdd.rounded_rectangle([(10, 10), (bw4, bh4)], radius=20, fill=(255, 245, 220, 240), outline=(220, 20, 60, 255), width=4)
    # Tail pointing towards Baby's face
    tail = [(bw4 - 25, bh4 - 15), (bw4 + 45, bh4 + 18), (bw4 - 10, bh4 - 35)]
    bdd.polygon(tail, fill=(255, 245, 220, 240), outline=(220, 20, 60, 255))
    bdd.line([(bw4 - 25, bh4 - 15), (bw4 - 10, bh4 - 35)], fill=(255, 245, 220, 255), width=5)
    
    font4 = ImageFont.truetype(font_path, 34)
    text4 = "「矢野はやべぇだろ」"
    bbox4 = bdd.textbbox((0, 0), text4, font=font4)
    tw4 = bbox4[2] - bbox4[0]
    th4 = bbox4[3] - bbox4[1]
    tx4 = (bw4 - tw4) // 2 + 5
    ty4 = (bh4 - th4) // 2 - 2
    
    draw_text_with_outline(
        bdd, (tx4, ty4), text4, font4,
        fill_color=(200, 10, 40, 255),        # Crimson text
        stroke_color=(255, 255, 255, 255),
        stroke_width=2,
        shadow_color=(0, 0, 0, 160),
        shadow_offset=(2, 2)
    )
    im4.paste(bubble, (520, 315), bubble)
    im4.convert('RGB').save('scratch/yano_opt4_manga_bubble.jpg', quality=95)
    im4.convert('RGB').save('C:/Users/user/Desktop/和気上等_4_吹き出しセリフ風.jpg', quality=95)
    print("Candidate 4 saved.")

if __name__ == '__main__':
    main()
