#!/usr/bin/env python3

"""
Расширение ASU API для поддержки динамической конфигурации
"""

import json
from pathlib import Path
from fastapi import APIRouter
from typing import Dict, List, Any

router = APIRouter()

CONFIG_FILE = Path("/opt/asu-server/imagebuilders.json")

@router.get("/config")
async def get_dynamic_config() -> Dict[str, Any]:
    """Возвращает динамическую конфигурацию для firmware-selector"""
    
    config = {
        "versions": [],
        "version_names": {},
        "target_names": {},
        "custom_feeds": [],
        "default_version": "24.10"
    }
    
    # Загрузка конфигурации Image Builder
    if CONFIG_FILE.exists():
        with open(CONFIG_FILE) as f:
            data = json.load(f)
            imagebuilders = data.get("imagebuilders", [])
            
            # Сбор уникальных версий
            versions = set()
            version_names = {}
            targets_by_version = {}
            
            for ib in imagebuilders:
                if ib.get("enabled", True):
                    version = ib["version"]
                    versions.add(version)
                    version_names[version] = ib.get("name", f"OpenWrt {version}")
                    
                    if version not in targets_by_version:
                        targets_by_version[version] = []
                    targets_by_version[version].append(ib["target"])
            
            config["versions"] = sorted(list(versions))
            config["version_names"] = version_names
            config["targets_by_version"] = targets_by_version
    
    # Загрузка кастомных фидов
    custom_feeds_file = Path("/opt/asu-server/custom_feeds.json")
    if custom_feeds_file.exists():
        with open(custom_feeds_file) as f:
            config["custom_feeds"] = json.load(f)
    
    return config

@router.get("/imagebuilders")
async def list_imagebuilders() -> List[Dict[str, Any]]:
    """Возвращает список всех Image Builder"""
    
    if not CONFIG_FILE.exists():
        return []
    
    with open(CONFIG_FILE) as f:
        data = json.load(f)
        return data.get("imagebuilders", [])

@router.post("/imagebuilders/refresh")
async def refresh_imagebuilders():
    """Обновляет конфигурацию ASU после изменений"""
    
    # Здесь можно добавить логику перезагрузки конфигурации
    # Например, отправка сигнала воркерам для перечитывания конфигурации
    
    return {"status": "refreshed"}

# Добавление роутера к основному приложению ASU
def setup_config_api(app):
    """Добавляет API конфигурации к ASU приложению"""
    app.include_router(router, prefix="/api")