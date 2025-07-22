import datetime
import os
from django.shortcuts import get_object_or_404, redirect, render
from django.views.decorators.http import require_POST
from django.http import HttpResponse
from django.contrib import messages
from django.contrib.auth.decorators import login_required,user_passes_test
from django import forms
from django.db import transaction 
from django.conf import settings
from django.core.paginator import Paginator,EmptyPage, PageNotAnInteger
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.platypus import Table, TableStyle, Paragraph
from reportlab.lib.styles import getSampleStyleSheet
from reportlab.lib.enums import TA_RIGHT, TA_LEFT, TA_CENTER
from decimal import Decimal

from .models import Brand, Category, Furniture,Order,OrderItem, Furniture, CustomUser, UserMembershipLog
from .forms import CategoryForm, CustomUserCreationForm, CustomUserUpdateForm, FurnitureForm, OrderForm
from django.shortcuts import render, get_object_or_404
from django.core.paginator import Paginator, EmptyPage, PageNotAnInteger
from .models import Furniture, Category, Brand 

def category_list(request):
    top_level_categories = Category.objects.filter(parent__isnull=True).order_by('name')
    context = {
        'categories': top_level_categories,
    }
    return render(request, 'main/category_list.html', context)


def furniture_list(request, category_slug=None, brand_slug=None):
    page_number = request.GET.get('page')
    request_category_id = request.GET.get('category_id')
    search_query = request.GET.get('q', '').strip()
    furniture_items = Furniture.objects.filter(is_visible=True)
    selected_category = None
    selected_brand = None

    # --- Category Filtering Logic ---
    if request_category_id:
        try:
            selected_category = Category.objects.get(pk=request_category_id)
            categories_to_include = [selected_category.pk]
            def get_all_children_pks(category_obj):
                children_pks = []
                for child in category_obj.children.all():
                    children_pks.append(child.pk)
                    children_pks.extend(get_all_children_pks(child))
                return children_pks
            categories_to_include.extend(get_all_children_pks(selected_category))
            furniture_items = furniture_items.filter(category__pk__in=categories_to_include)
        except Category.DoesNotExist:
            furniture_items = Furniture.objects.none()

    if brand_slug:
        try:
            selected_brand = get_object_or_404(Brand, slug=brand_slug)
            furniture_items = furniture_items.filter(brand=selected_brand)
        except Brand.DoesNotExist:
            furniture_items = Furniture.objects.none()

    # --- Search Filtering Logic ---
    if search_query:
        from django.db.models import Q
        furniture_items = furniture_items.filter(
            Q(name__icontains=search_query) |
            Q(description__icontains=search_query) |
            Q(item_code__icontains=search_query)
        )

    furniture_items = furniture_items.order_by('name')
    paginator = Paginator(furniture_items, 9)  # Show 9 items per page
    try:
        page_obj = paginator.page(page_number)
    except PageNotAnInteger:
        page_obj = paginator.page(1)
    except EmptyPage:
        page_obj = paginator.page(paginator.num_pages)

    categories = Category.objects.filter(parent__isnull=True).prefetch_related('children__children__children').order_by('name')
    recommended_items = Furniture.objects.filter(is_visible=True).order_by('?')[:8] # Get 8 random items
    featured_items = Furniture.objects.filter(is_visible=True, featured=True).order_by('-id')[:8] # Get 8 featured items
    own_brand_name = 'INHOUSE'

    try:
        own_brand = Brand.objects.get(name=own_brand_name)
        other_brands = Brand.objects.exclude(name=own_brand_name).order_by('name')
        all_brands_ordered = [own_brand] + list(other_brands)
    except Brand.DoesNotExist:
        all_brands_ordered = Brand.objects.all().order_by('name')
    context = {
        'page_obj': page_obj,
        'items': page_obj.object_list,
        'categories': categories,
        'brands': all_brands_ordered,
        'selected_category': selected_category,
        'selected_category_id': int(request_category_id) if request_category_id else None,
        'selected_brand': selected_brand,
        'recommended_items': recommended_items,
        'featured_items': featured_items,
        'search_query': search_query,
    }
    return render(request, 'main/furniture_list.html', context)

def furniture_detail(request,pk):
    item = get_object_or_404(Furniture,pk=pk)
    return render(request, 'main/furniture_detail.html',{'item':item})

# def brand_detail(request, brand_slug):
#     brand = get_object_or_404(Brand, slug=brand_slug)
#     items = Furniture.objects.filter(brand=brand).order_by('name')

#     categories = Category.objects.filter(parent__isnull=True).prefetch_related('children__children__children').order_by('name')
#     all_brands = Brand.objects.all().order_by('name') # For the sidebar

#     context = {
#         'brand': brand,
#         'items': items,
#         'categories': categories, 
#         'brands': all_brands, 
#     }
#     return render(request, 'main/brand_detail.html', context)
def brand_detail(request, brand_slug):
    brand = get_object_or_404(Brand, slug=brand_slug)
    items = Furniture.objects.filter(brand=brand).order_by('name')

    # Add pagination
    page_number = request.GET.get('page')
    paginator = Paginator(items, 9)  # Show 9 items per page
    try:
        page_obj = paginator.page(page_number)
    except PageNotAnInteger:
        page_obj = paginator.page(1)
    except EmptyPage:
        page_obj = paginator.page(paginator.num_pages)

    categories = Category.objects.filter(parent__isnull=True).prefetch_related('children__children__children').order_by('name')
    all_brands = Brand.objects.all().order_by('name')  # For the sidebar

    context = {
        'brand': brand,
        'page_obj': page_obj,
        'items': page_obj.object_list,
        'categories': categories,
        'brands': all_brands,
    }
    return render(request, 'main/brand_detail.html', context)

def add_to_cart(request, pk):
    cart = request.session.get('cart', {})
    pk_str = str(pk)

    try:
        quantity = int(request.POST.get('quantity', 1))
    except ValueError:
        quantity = 1

    if pk_str in cart:
        cart[pk_str] += quantity
    else:
        cart[pk_str] = quantity

    request.session['cart'] = cart
    print(pk_str, "your cart now has", cart[pk_str], "items.")
    return redirect('furniture_list')

def view_cart(request):
    cart = request.session.get('cart',{})
    items=[]
    total=0
    for pk, qty in cart.items():
        try:
            furniture = Furniture.objects.get(pk=pk)
            subtotal = furniture.price * qty
            total += subtotal
            items.append({
                'furniture': furniture,
                'quantity': qty,
                'subtotal': subtotal
            })
        except Furniture.DoesNotExist:
            continue
    return render(request, 'main/cart.html',{'items':items,'total':total})

@require_POST
def update_cart(request,pk):
    cart= request.session.get('cart',{})
    quantity = int(request.POST.get('quantity',1))
    if quantity >0:
        cart[str(pk)]=quantity
    else:
        cart.pop(str(pk),None)
    request.session['cart']=cart
    return redirect('view_cart')

def remove_from_cart(request,pk):
    cart = request.session.get('cart',{})
    cart.pop(str(pk),None)
    request.session['cart']= cart
    return redirect('view_cart')

from django.contrib.auth import login
from django.core.mail import send_mail

def register(request):
    next_url = request.GET.get('next') or request.POST.get('next') or 'furniture_list'
    if request.method == 'POST':
        form = CustomUserCreationForm(request.POST)
        if form.is_valid():
            user = form.save()
            login(request, user)
            # Send welcome email
            send_mail(
                'Welcome to Our Furniture Store!',
                f'Hi {user.username}, thanks for registering!',
                'kgmobile.service@gmial.com',
                [user.email],
                fail_silently=True
            )
            return redirect(next_url)
    else:
        form = CustomUserCreationForm()
    return render(request, 'main/register.html', {'form': form})

from django.contrib.auth.decorators import login_required

@login_required
def profile(request):
    member_level_colors = {
        'Gold': 'bg-yellow-100 border-yellow-300',    # Light yellow background for Gold
        'Silver': 'bg-gray-100 border-gray-300',     # Light gray for Silver
        'Bronze': 'bg-amber-50 border-amber-200',    # Very light orange/amber for Bronze
        'Platinum': 'bg-blue-100 border-blue-300',   # Light blue for Platinum
        'Default': 'bg-white border-gray-200',      # Default white background
    }
    user_member_level = request.user.member_level if request.user.member_level else 'Default'
    background_classes = member_level_colors.get(user_member_level, member_level_colors['Default'])
    context = {
        'background_classes': background_classes,
    }
    return render(request, 'main/profile.html', context)

def get_session_cart(request):
    return request.session.get('cart', {}) # cart = {'furniture_id': quantity, ...}
def clear_session_cart(request):
    if 'cart' in request.session:
        del request.session['cart']

@login_required
def checkout_view(request):
    cart = get_session_cart(request)
    if not cart:
        return redirect('furniture_list') # Or some other appropriate page
    cart_items_data = []
    total_cart_amount = 0
    for furniture_id, quantity in cart.items():
        try:
            furniture = Furniture.objects.get(id=furniture_id)
            item_total = furniture.price * quantity
            cart_items_data.append({
                'furniture': furniture,
                'quantity': quantity,
                'price': furniture.price,
                'total': item_total
            })
            total_cart_amount += item_total
        except Furniture.DoesNotExist:
            continue

    if request.method == 'POST':
        form = OrderForm(request.POST)
        if form.is_valid():
            with transaction.atomic():
                order = Order.objects.create(
                    user=request.user,
                    customer_name=form.cleaned_data['customer_name'],
                    customer_address=form.cleaned_data['customer_address'],
                    customer_phone=form.cleaned_data['customer_phone'],
                    payment_method=form.cleaned_data['payment_method'],
                    total_amount=total_cart_amount, # Set calculated total
                    status='Pending',
                    payment_status='Pending'
                )
                for item_data in cart_items_data:
                    OrderItem.objects.create(
                        order=order,
                        furniture=item_data['furniture'],
                        quantity=item_data['quantity'],
                        price_at_purchase=item_data['price'] # Use price at time of purchase
                    )
                clear_session_cart(request) # Clear cart after successful order
                return redirect('main/order_success', order_id=order.id) # Redirect to success page
    else:
        initial_data = {
            'customer_name': request.user.username,
            'customer_address': request.user.address if hasattr(request.user, 'address') else '', # Assuming user might have address
            'customer_phone': request.user.phone,
        }
        form = OrderForm(initial=initial_data)
    context = {
        'form': form,
        'cart_items_data': cart_items_data,
        'total_cart_amount': total_cart_amount,
    }
    return render(request, 'main/checkout.html', context)

@login_required
def order_success_view(request, order_id):
    order = get_object_or_404(Order, id=order_id, user=request.user)
    return render(request, 'main/order_success.html', {'order': order})

@login_required
def user_order_history(request):
    orders = Order.objects.filter(user=request.user).order_by('-created_at')
    context = {'orders': orders}
    return render(request, 'main/order_history.html', context)

# before order cancellation feature added
@login_required
def order_detail(request, order_id):
    order = get_object_or_404(Order, id=order_id, user=request.user)
    context = {'order': order}
    return render(request, 'main/order_detail.html', context)

def generate_invoice_pdf(request, order_id):
    order = get_object_or_404(Order, id=order_id, user=request.user)
    
    response = HttpResponse(content_type='application/pdf')
    response['Content-Disposition'] = f'attachment; filename="Invoice_Order_{order.order_number}.pdf"'

    p = canvas.Canvas(response, pagesize=A4)
    width, height = A4
    styles = getSampleStyleSheet()
    
    GOLD_COLOR = colors.HexColor("#DAA520") # Primary accent gold
    DARK_GRAY = colors.HexColor("#333333")  # Dark text/header elements
    LIGHT_GRAY = colors.HexColor("#F8F8F8") # Light background for alternating rows
    BORDER_GRAY = colors.HexColor("#E0E0E0") # Light border color
    MEDIUM_GRAY = colors.HexColor("#666666") # Secondary text color
    WATERMARK_COLOR = colors.HexColor("#DAA520") # Use gold for watermark, or a very light gray
    logo_path = os.path.join(settings.STATIC_ROOT, 'img', 'logop.png') # Adjust this path

    # --- Company Information ---
    company_name = "INHOUSE Luxury Furniture"
    company_address_line1 = "No.150/151, Bo Aung Kyaw Road,Shwe Than Lwin Industrial Zone,"
    company_address_line2 = "Hlaing Thar Yar Tsp, Yangon, Myanamr."
    company_phone = "+959-443887880,+959-443887881"
    company_email = "info@inhousemm.com"

    p.saveState() # Save the current canvas state before applying transformations
    p.setFillColor(WATERMARK_COLOR)
    p.setStrokeColor(WATERMARK_COLOR)
    p.setDash(1, 0) # Solid line (no dashes)

    p.setFillAlpha(0.1) # Slightly lower opacity for a full-page watermark
    p.setStrokeAlpha(0.1)

    p.translate(width/2.0, height/2.0)
    p.rotate(45) # Rotate 45 degrees

    watermark_text = "INHOUSE"
    font_size = 30
    p.setFont("Helvetica-Bold", font_size)


    text_width_approx = p.stringWidth(watermark_text, "Helvetica-Bold", font_size)
    text_height_approx = font_size * 1.2

    x_spacing = text_width_approx * 1.5
    y_spacing = text_height_approx * 3.0

    
    # Loop over X-axis
    for x_offset in range(int(-width * 0.7), int(width * 0.7), int(x_spacing)):
        # Loop over Y-axis
        for y_offset in range(int(-height * 0.7), int(height * 0.7), int(y_spacing)):
            p.drawCentredString(x_offset, y_offset, watermark_text)

    p.restoreState() 
    # === End Watermark ===

########################logo image
    try:
            if os.path.exists(logo_path):
                logo_width = 6 * cm  
                logo_height = 2.5 * cm 
                p.drawImage(logo_path,width- 8 * cm, height - 6.5 * cm, width=logo_width, height=logo_height, preserveAspectRatio=True)
    
            else:
                print(f"Logo file not found at: {logo_path}")
                company_info_y_offset = 3.5 * cm
                invoice_title_y_offset = 3.5 * cm

    except Exception as e:
        print(f"Error drawing logo: {e}") # For debugging
        company_info_y_offset = 3.5 * cm
        invoice_title_y_offset = 3.5 * cm

    # === Header & Company Details ===
    p.setFont("Helvetica-Bold", 32) # Larger, more impactful invoice title
    p.setFillColor(GOLD_COLOR)
    p.drawRightString(width - 2.5 * cm, height - 3.5 * cm, "INVOICE") # Right-aligned

    p.setFont("Helvetica-Bold", 14)
    p.setFillColor(DARK_GRAY)
    p.drawString(2.5 * cm, height - 5.5 * cm, company_name)
    p.setFont("Helvetica", 9) 
    p.setFillColor(MEDIUM_GRAY)
    p.drawString(2.5 * cm, height - 6.0 * cm, company_address_line1)
    p.drawString(2.5 * cm, height - 6.4 * cm, company_address_line2)
    p.drawString(2.5 * cm, height - 6.8 * cm, f"Phone: {company_phone}")
    p.drawString(2.5 * cm, height - 7.2 * cm, f"Email: {company_email}")

    # Horizontal line separator below company details
    p.setStrokeColor(BORDER_GRAY)
    p.setLineWidth(0.7) # Slightly thicker line
    p.line(2.5 * cm, height - 7.8 * cm, width - 2.5 * cm, height - 7.8 * cm)

    # === Invoice Details & Customer Info ===
    y_start_info_block = height - 8.8 * cm

    # Invoice Details (Right side, aligned with invoice title)
    p.setFont("Helvetica-Bold", 11)
    p.setFillColor(DARK_GRAY)
    p.drawRightString(width - 2.5 * cm, y_start_info_block, "Invoice Details:")
    p.setFont("Helvetica", 10)
    p.setFillColor(MEDIUM_GRAY)
    p.drawRightString(width - 2.5 * cm, y_start_info_block - 0.6 * cm, f"Invoice No: {order.order_number}")
    p.drawRightString(width - 2.5 * cm, y_start_info_block - 1.2 * cm, f"Date: {order.created_at.strftime('%B %d, %Y')}")
    p.drawRightString(width - 2.5 * cm, y_start_info_block - 1.8 * cm, f"Time: {order.created_at.strftime('%H:%M')}")
    p.drawRightString(width - 2.5 * cm, y_start_info_block - 2.4 * cm, f"Status: {order.get_status_display()}")
    p.drawRightString(width - 2.5 * cm, y_start_info_block - 3.0 * cm, f"Payment Status: {order.get_payment_status_display()}")


    # Customer Info (Left side)
    p.setFont("Helvetica-Bold", 11)
    p.setFillColor(DARK_GRAY)
    p.drawString(2.5 * cm, y_start_info_block, "Bill To:")
    p.setFont("Helvetica", 10)
    p.setFillColor(MEDIUM_GRAY)
    p.drawString(2.5 * cm, y_start_info_block - 0.6 * cm, order.customer_name)
    p.drawString(2.5 * cm, y_start_info_block - 1.2 * cm, order.customer_address)
    p.drawString(2.5 * cm, y_start_info_block - 1.8 * cm, f"Phone: {order.customer_phone}")
    p.drawString(2.5 * cm, y_start_info_block - 2.4 * cm, f"Payment Method: {order.payment_method}")

    # --- Order Items Table ---
    data = [
        [Paragraph("<b>Item Description</b>", styles['Normal']), Paragraph("<b>Qty</b>", styles['Normal']), Paragraph("<b>Unit Price</b>", styles['Normal']), Paragraph("<b>Total</b>", styles['Normal'])]
    ]
    for item in order.items.all():
        data.append([
            Paragraph(item.furniture.name, styles['Normal']),
            str(item.quantity),
            f"${item.price_at_purchase:.2f}",
            f"${item.get_total():.2f}"
        ])

    table_y_start = y_start_info_block - 4.5 * cm # Position table below info blocks
    
    # Define table style
    table_style = TableStyle([
        ('BACKGROUND', (0, 0), (-1, 0), GOLD_COLOR), # Header background
        ('TEXTCOLOR', (0, 0), (-1, 0), colors.white), # Header text color
        ('ALIGN', (0, 0), (0, -1), 'LEFT'), # Item Description left-aligned
        ('ALIGN', (1, 0), (-1, -1), 'CENTER'), # Qty, Unit Price, Total centered
        ('ALIGN', (2, 0), (-1, -1), 'RIGHT'), # Unit Price and Total right-aligned for numbers
        ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'), # Header font
        ('FONTSIZE', (0, 0), (-1, 0), 10), # Header font size
        ('BOTTOMPADDING', (0, 0), (-1, 0), 8), # Header padding
        ('TOPPADDING', (0, 0), (-1, 0), 8), # Header padding
        ('GRID', (0, 0), (-1, -1), 0.5, BORDER_GRAY), # All borders
        ('VALIGN', (0, 0), (-1, -1), 'MIDDLE'), # Vertical alignment
        ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'), # Body font
        ('FONTSIZE', (0, 1), (-1, -1), 9), # Body font size
    ])

    # Apply alternating row background
    for i in range(1, len(data)):
        if i % 2 == 0:
            table_style.add('BACKGROUND', (0, i), (-1, i), LIGHT_GRAY)
        else:
            table_style.add('BACKGROUND', (0, i), (-1, i), colors.white)


    # Column widths (adjust as needed for content)
    col_widths = [8.5 * cm, 2 * cm, 3 * cm, 3 * cm] # Item, Qty, Unit Price, Total

    table = Table(data, colWidths=col_widths)
    table.setStyle(table_style)

    # Draw table
    table_width, table_height = table.wrapOn(p, width, height)
    p.saveState() # Save current state
    table.drawOn(p, 2.5 * cm, table_y_start - table_height) # Position table
    p.restoreState() # Restore state

    current_y = table_y_start - table_height

    # --- Total Section ---
    total_section_start_y = current_y - 1.5 * cm

    subtotal = sum(item.get_total() for item in order.items.all())
    tax_rate = Decimal('0.05') 
    shipping_cost = Decimal('25.00') 
    tax_amount = subtotal * tax_rate
    grand_total = subtotal + tax_amount + shipping_cost

    # Draw lines for totals
    p.setStrokeColor(BORDER_GRAY)
    p.setLineWidth(0.5)
    
    # Subtotal, Tax, Shipping
    p.setFont("Helvetica", 10)
    p.setFillColor(DARK_GRAY)
    p.drawRightString(width - 5 * cm, total_section_start_y, "Subtotal:")
    p.drawRightString(width - 2.5 * cm, total_section_start_y, f"${subtotal:.2f}")

    p.drawRightString(width - 5 * cm, total_section_start_y - 0.7 * cm, f"Tax ({tax_rate * 100:.0f}%):")
    p.drawRightString(width - 2.5 * cm, total_section_start_y - 0.7 * cm, f"${tax_amount:.2f}")

    p.drawRightString(width - 5 * cm, total_section_start_y - 1.4 * cm, "Shipping:")
    p.drawRightString(width - 2.5 * cm, total_section_start_y - 1.4 * cm, f"${shipping_cost:.2f}")

    # Line above Grand Total
    p.setLineWidth(1) # Thicker line
    p.line(width - 7.5 * cm, total_section_start_y - 1.8 * cm, width - 2.5 * cm, total_section_start_y - 1.8 * cm)

    # Grand Total
    p.setFont("Helvetica-Bold", 16) # Larger, bolder for grand total
    p.setFillColor(GOLD_COLOR)
    p.drawRightString(width - 5 * cm, total_section_start_y - 2.8 * cm, "GRAND TOTAL:")
    p.drawRightString(width - 2.5 * cm, total_section_start_y - 2.8 * cm, f"${grand_total:.2f}")


    # === Footer ===
    p.setFillColor(MEDIUM_GRAY)
    p.setFont("Helvetica-Oblique", 9)
    p.setLineWidth(0.5)
    p.line(2.5 * cm, 2.5 * cm, width - 2.5 * cm, 2.5 * cm) # Line above footer
    p.drawCentredString(width / 2, 1.5 * cm, "Thank you for choosing INHOUSE Luxury Furniture. We appreciate your business!")

    p.showPage()
    p.save()
    return response

