#!/usr/bin/env python3
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.units import inch
from reportlab.lib.colors import HexColor
import os
import re

def parse_markdown(md_path):
    with open(md_path, 'r') as f:
        content = f.read()
    
    # Split into text and diagram sections
    parts = content.split('---')
    text_section = parts[0].strip()
    diagram_section = parts[1].strip() if len(parts) > 1 else ""
    
    # Parse title
    title_match = re.search(r'^## (.+)$', text_section, re.MULTILINE)
    title = title_match.group(1) if title_match else "Untitled"
    
    # Parse overview
    overview_match = re.search(r'### Overview\s+(.+?)(?=###|\Z)', text_section, re.DOTALL)
    overview_text = overview_match.group(1).strip() if overview_match else ""
    
    # Parse features
    features_match = re.search(r'### Features\s+(.+?)(?=###|\Z)', text_section, re.DOTALL)
    features_text = features_match.group(1).strip() if features_match else ""
    
    # Parse each demo section
    demos = []
    demo_pattern = r'\*\*(.+?)\*\*\s*\n((?:[ ]*- .+\n?)+)'
    for match in re.finditer(demo_pattern, features_text):
        demo_title = match.group(1)
        items_text = match.group(2)
        items = []
        for line in items_text.strip().split('\n'):
            # Count leading spaces to determine nesting level
            stripped = line.lstrip()
            indent = len(line) - len(stripped)
            if stripped.startswith('- '):
                nested = indent > 0
                items.append((stripped[2:], nested))  # (text, is_nested)
        demos.append((demo_title, items))
    
    # Extract diagram lines
    diagram_lines = [line for line in diagram_section.split('\n') if line.strip()]
    
    return {
        'title': title,
        'overview': overview_text,
        'demos': demos,
        'diagrams': diagram_lines
    }

def create_pdf(output_path, md_path):
    data = parse_markdown(md_path)
    
    c = canvas.Canvas(output_path, pagesize=letter)
    width, height = letter
    
    try:
        pdfmetrics.registerFont(TTFont('Menlo', '/System/Library/Fonts/Menlo.ttc'))
        mono_font = 'Menlo'
    except:
        mono_font = 'Courier'
    
    margin_left = 0.75 * inch
    margin_right = 0.75 * inch
    margin_top = 0.75 * inch
    
    blue = HexColor('#0066CC')
    dark_gray = HexColor('#333333')
    light_gray = HexColor('#666666')
    
    y = height - margin_top
    
    def draw_title(text, size=18):
        nonlocal y
        c.setFont('Helvetica-Bold', size)
        c.setFillColor(dark_gray)
        c.drawString(margin_left, y, text)
        y -= size + 8
    
    def draw_heading(text, size=13):
        nonlocal y
        y -= 6
        c.setFont('Helvetica-Bold', size)
        c.setFillColor(blue)
        c.drawString(margin_left, y, text)
        y -= size + 4
    
    def draw_subheading(text, size=11):
        nonlocal y
        c.setFont('Helvetica-Bold', size)
        c.setFillColor(dark_gray)
        c.drawString(margin_left, y, text)
        y -= size + 3
    
    def draw_body(text, size=9):
        nonlocal y
        c.setFont('Helvetica', size)
        c.setFillColor(dark_gray)
        c.drawString(margin_left, y, text)
        y -= size + 3
    
    def draw_mono(text, size=6.0):
        nonlocal y
        c.setFont(mono_font, size)
        c.setFillColor(dark_gray)
        c.drawString(margin_left, y, text)
        y -= size * 1.25
    
    def space(pixels=10):
        nonlocal y
        y -= pixels
    
    def draw_separator():
        nonlocal y
        y -= 8
        c.setStrokeColor(HexColor('#CCCCCC'))
        c.setLineWidth(0.5)
        c.line(margin_left, y, width - margin_right, y)
        y -= 12
    
    # Title
    draw_title(data['title'])
    space(4)
    
    # Overview
    draw_heading("Overview")
    
    # Parse overview - handle **Use Case:** format
    overview = data['overview']
    use_case_match = re.match(r'\*\*Use Case:\*\*\s*(.+)', overview)
    if use_case_match:
        first_line = use_case_match.group(1).split('\n')[0]
        c.setFont('Helvetica-Bold', 9)
        c.setFillColor(dark_gray)
        c.drawString(margin_left, y, "Use Case: ")
        c.setFont('Helvetica', 9)
        c.drawString(margin_left + 48, y, first_line)
        y -= 14
        
        # Remaining overview text
        remaining = overview[overview.find('\n')+1:].strip() if '\n' in overview else ""
        if remaining:
            # Wrap text at ~100 chars
            words = remaining.split()
            lines = []
            current_line = []
            for word in words:
                current_line.append(word)
                if len(' '.join(current_line)) > 95:
                    current_line.pop()
                    lines.append(' '.join(current_line))
                    current_line = [word]
            if current_line:
                lines.append(' '.join(current_line))
            for line in lines:
                draw_body(line)
    else:
        draw_body(overview[:100])
    
    space(6)
    
    # Features
    draw_heading("Features")
    
    for title, items in data['demos']:
        draw_subheading(title)
        for item, nested in items:
            indent = 20 if nested else 0
            c.setFont('Helvetica', 9)
            c.setFillColor(light_gray)
            c.drawString(margin_left + 10 + indent, y, "•")
            c.setFillColor(dark_gray)
            # Truncate if too long
            max_width = width - margin_right - (margin_left + 22 + indent)
            display_text = item
            while c.stringWidth(display_text, 'Helvetica', 9) > max_width and len(display_text) > 10:
                display_text = display_text[:-4] + "..."
            c.drawString(margin_left + 22 + indent, y, display_text)
            y -= 12
        space(3)
    
    draw_separator()
    
    # Architecture Diagrams
    draw_heading("Architecture")
    space(4)
    
    c.setFillColor(dark_gray)
    for line in data['diagrams']:
        draw_mono(line, 6.0)
    
    c.save()
    print(f"PDF created: {output_path}")

if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    md_path = os.path.join(script_dir, "arch_diagram.md")
    pdf_path = os.path.join(script_dir, "arch_diagram.pdf")
    create_pdf(pdf_path, md_path)
