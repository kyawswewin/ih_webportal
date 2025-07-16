from django.urls import path

from customize import views

urlpatterns = [
    path('create/', views.create_wardrobe, name='create_wardrobe'),
    path('<int:pk>/', views.wardrobe_detail, name='wardrobe_detail'),
    path('<int:pk>/3d/', views.wardrobe_3d_view, name='wardrobe_3d_view'),
]
