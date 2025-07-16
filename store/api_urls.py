from django.urls import path
from . import api_views
from rest_framework.authtoken.views import ObtainAuthToken
from django.views.decorators.csrf import csrf_exempt


urlpatterns = [
    path('register/', api_views.api_register, name='api_register'),
    path('login/', csrf_exempt(api_views.api_login), name='api_login'),
    path('profile/', api_views.api_profile, name='api_profile'),

    path('categories/', api_views.api_categories, name='api_categories'),
    path('furniture/', api_views.api_furniture_list, name='api_furniture_list'),
    path('furniture/<int:pk>/', api_views.api_furniture_detail, name='api_furniture_detail'),

    path('orders/create/', csrf_exempt(api_views.api_create_order), name='api_create_order'),
    path('orders/history/', api_views.api_user_order_history, name='api_order_history'),
    path('orders/<int:pk>/', api_views.api_order_detail, name='api_order_detail'),
]
