from django.urls import path
from .views import DiseaseList, FloraList, OutbreakList, FarmerList, MapDataView

urlpatterns = [
    path('diseases/', DiseaseList.as_view()),
    path('symptoms/', DiseaseList.as_view()),  # alias
    path('flora/', FloraList.as_view()),
    path('outbreaks/', OutbreakList.as_view()),
    path('farmers/', FarmerList.as_view()),
    path('map-farmers/', MapDataView.as_view()),
]
