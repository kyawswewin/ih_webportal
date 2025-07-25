from django.urls import path
from . import views_staff

urlpatterns = [

    path('', views_staff.staff_dashboard, name='staff_dashboard'),

    path('orders/', views_staff.staff_order_list, name='staff_order_list'),
    path('orders/<int:order_id>/', views_staff.staff_order_detail, name='staff_order_detail'),

    path('furniture/', views_staff.staff_furniture_list, name='staff_furniture_list'),
    path('furniture/add/', views_staff.staff_furniture_manage, name='staff_furniture_add'),
    path('furniture/edit/<int:pk>/', views_staff.staff_furniture_manage, name='staff_furniture_edit'),
    path('furniture/delete/<int:pk>/', views_staff.staff_furniture_delete, name='staff_furniture_delete'),

    path('customers/', views_staff.staff_customer_list, name='staff_customer_list'),
    path('customers/<int:pk>/', views_staff.staff_customer_detail, name='staff_customer_detail'),

    path('mbl/', views_staff.staff_mbl_list, name='staff_mbl_list'),
    path('mbl/<int:pk>/', views_staff.staff_mbl_detail, name='staff_mbl_detail'),
   
    path('memberlevels/', views_staff.staff_memberlevel_list, name='staff_memberlevel_list'),

    path('categories/', views_staff.staff_category_list, name='staff_category_list'),
    path('categories/edit/<int:pk>/', views_staff.staff_category_edit, name='staff_category_edit'),
    path('categories/delete/<int:pk>/', views_staff.staff_category_delete, name='staff_category_delete'),

    path('db-backup/', views_staff.db_backup, name='staff_db_backup'),
    path('db-restore/', views_staff.db_restore, name='staff_db_restore'),

    path('exchange-rates/logs/', views_staff.exchange_rate_logs, name='exchange_rate_logs'),
    path('exchange-rates/list/', views_staff.exchange_rate_list, name='exchange_rate_list'),
    path('exchange-rates/create/', views_staff.create_exchange_rate, name='create_exchange_rate'),
    path('exchange-rates/<str:currency>/update/', views_staff.update_exchange_rate, name='update_exchange_rate'),
]