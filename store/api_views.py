from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from django.shortcuts import get_object_or_404
from django.db import transaction
from django.contrib.auth import get_user_model
from rest_framework.authtoken.models import Token
from django.core.mail import send_mail
from django.contrib.auth.hashers import make_password
from django.views.decorators.csrf import csrf_exempt
from .models import Category, Furniture, Order, OrderItem
from .serializers import (
    FurnitureSerializer, 
    CategorySerializer, 
    OrderSerializer
)

User = get_user_model()

@csrf_exempt
@api_view(['POST'])
def api_login(request):
    username = request.data.get('username')
    password = request.data.get('password')

    from django.contrib.auth import authenticate
    user = authenticate(username=username, password=password)

    if user:
        token, _ = Token.objects.get_or_create(user=user)
        return Response({'token': token.key})
    return Response({'non_field_errors': ['Invalid credentials']}, status=400)

# 1. Register API
@csrf_exempt
@api_view(['POST'])
def api_register(request):
    data = request.data
    if data.get("password") != data.get("password2"):
        return Response({'error': 'Passwords do not match.'}, status=400)

    try:
        user = User.objects.create(
            username=data["username"],
            email=data.get("email", ""),
            phone=data.get("phone", ""),
            nrc=data.get("nrc", ""),
            dob=data.get("dob", ""),
            password=make_password(data["password"]),
            createdby="Mobile"
        )
    except Exception as e:
        return Response({'error': str(e)}, status=400)

    token, _ = Token.objects.get_or_create(user=user)

    # Optional email
    if user.email:
        try:
            send_mail(
                "Welcome to Furniture Store",
                f"Hello {user.username}, welcome!",
                "admin@example.com",
                [user.email],
                fail_silently=True,
            )
        except:
            pass

    return Response({
        'message': 'User registered successfully.',
        'token': token.key,
        'username': user.username,
        'user_id': user.id,
        'c_code': user.c_code
    }, status=201)

# 2. Login/Profile View
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def api_profile(request):
    user = request.user
    return Response({
        'username': user.username,
        'email': user.email,
        'phone': user.phone,
        'nrc': user.nrc,
        'dob': user.dob,
        'c_code': user.c_code,
        'member_level': user.member_level,
        'amount': user.amount,
        'date_joined':user.date_joined
    })

# 3. Category List API
@api_view(['GET'])
def api_categories(request):
    categories = Category.objects.all()
    serializer = CategorySerializer(categories, many=True)
    return Response(serializer.data)

# 4. Furniture List API (with optional category filter)
@api_view(['GET'])
def api_furniture_list(request):
    category = request.GET.get('category')
    if category:
        furniture = Furniture.objects.filter(category__name__iexact=category)
    else:
        furniture = Furniture.objects.all()

    serializer = FurnitureSerializer(furniture, many=True, context={'request': request})
    return Response(serializer.data)

# 5. Furniture Detail API
@api_view(['GET'])
def api_furniture_detail(request, pk):
    item = get_object_or_404(Furniture, pk=pk)
    serializer = FurnitureSerializer(item, context={'request': request})
    return Response(serializer.data)

# 6. Create Order from Mobile
@csrf_exempt
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def api_create_order(request):
    data = request.data
    items = data.get("items")

    if not items or not isinstance(items, list):
        return Response({"error": "Items must be a non-empty list"}, status=400)

    try:
        with transaction.atomic():
            order = Order.objects.create(
                user=request.user,
                customer_name=data.get("customer_name", request.user.username),
                customer_address=data.get("customer_address", ""),
                customer_phone=data.get("customer_phone", ""),
                payment_method=data.get("payment_method", "Cash on Delivery"),
                status='Pending',
                payment_status='Pending'
            )

            total = 0
            for item in items:
                furniture = Furniture.objects.get(pk=item["furniture_id"])
                qty = int(item["quantity"])
                subtotal = furniture.price * qty
                OrderItem.objects.create(
                    order=order,
                    furniture=furniture,
                    quantity=qty,
                    price_at_purchase=furniture.price
                )
                total += subtotal

            order.total_amount = total
            order.save()
            serializer = OrderSerializer(order)
            return Response(serializer.data, status=201)
    except Furniture.DoesNotExist:
        return Response({"error": "Invalid furniture ID."}, status=400)
    except Exception as e:
        return Response({"error": str(e)}, status=500)

# 7. Order History
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def api_user_order_history(request):
    orders = Order.objects.filter(user=request.user).order_by('-created_at')
    serializer = OrderSerializer(orders, many=True)
    return Response(serializer.data)

# 8. Order Detail
@api_view(['GET'])
@permission_classes([IsAuthenticated])
def api_order_detail(request, pk):
    order = get_object_or_404(Order, pk=pk, user=request.user)
    serializer = OrderSerializer(order)
    return Response(serializer.data)
