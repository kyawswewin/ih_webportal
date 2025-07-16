from django.urls import path
from . import views

urlpatterns = [

    path('', views.staff_dashboard, name='staff_dashboard'),

    path('orders/', views.staff_order_list, name='staff_order_list'),
    path('orders/<int:order_id>/', views.staff_order_detail, name='staff_order_detail'),

    path('furniture/', views.staff_furniture_list, name='staff_furniture_list'),
    path('furniture/add/', views.staff_furniture_manage, name='staff_furniture_add'),
    path('furniture/edit/<int:pk>/', views.staff_furniture_manage, name='staff_furniture_edit'),
    path('furniture/delete/<int:pk>/', views.staff_furniture_delete, name='staff_furniture_delete'),

    path('customers/', views.staff_customer_list, name='staff_customer_list'),
    path('customers/<int:pk>/', views.staff_customer_detail, name='staff_customer_detail'),
   
    path('categories/', views.staff_category_list, name='staff_category_list'),
    path('categories/edit/<int:pk>/', views.staff_category_edit, name='staff_category_edit'),
    path('categories/delete/<int:pk>/', views.staff_category_delete, name='staff_category_delete'),
]