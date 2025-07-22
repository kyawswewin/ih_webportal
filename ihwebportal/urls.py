from django.contrib import admin
from django.urls import include, path
from django.conf import settings
from django.conf.urls.static import static
from .settings import MEDIA_ROOT,MEDIA_URL
from store import views as store_views
from django.contrib.auth import views as auth_views

urlpatterns = [
    path('admin/', admin.site.urls),
    path('',include('store.urls')),
    path('register/', store_views.register, name='register'),
    path('login/',auth_views.LoginView.as_view(template_name='login.html'),name='login'),
    path('logout/',auth_views.LogoutView.as_view(next_page='/'),name='logout'),
    path('api/', include('store.api_urls')),
    path('customize/', include('customize.urls')),
    path('staff/', include('store.urls_staff')),





]+static(settings.MEDIA_URL,document_root=settings.MEDIA_ROOT)
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)