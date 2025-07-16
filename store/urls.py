from django.urls import path
from . import views
from django.contrib.auth import views as auth_views

urlpatterns = [
    # --- Web Application Paths ---
    path('', views.furniture_list, name='furniture_list'),
    path('item/<int:pk>/', views.furniture_detail, name='furniture_detail'),

    # Cart Paths
    path('add-to-cart/<int:pk>', views.add_to_cart, name='add_to_cart'),
    path('cart/', views.view_cart, name='view_cart'),
    path('cart/update/<int:pk>/', views.update_cart, name='update_cart'),
    path('cart/remove/<int:pk>', views.remove_from_cart, name='remove_from_cart'),

    # Category Paths
    path('categories/', views.category_list, name='category_list'),

    # Authentication Paths
    path('register/', views.register, name='register'),
    path('login/', auth_views.LoginView.as_view(template_name='main/login.html'), name='login'),
    path('logout/', auth_views.LogoutView.as_view(), name='logout'),
    path('profile/', views.profile, name='profile'),

    # Order/Checkout Web Paths
    path('checkout/', views.checkout_view, name='checkout'),
    path('order/success/<int:order_id>/', views.order_success_view, name='order_success'),
    path('my-orders/', views.user_order_history, name='user_order_history'),
    path('my-orders/<int:order_id>/', views.order_detail, name='order_detail'),

    path('invoice/<int:order_id>/', views.generate_invoice_pdf, name='generate_invoice_pdf'),
    

    # brands
    path('furniture/brand/<slug:brand_slug>/', views.furniture_list, name='furniture_list_by_brand'),
    path('brands/<slug:brand_slug>/', views.brand_detail, name='brand_detail'), 

    
]

    

