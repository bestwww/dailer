# Исправление ошибки TimePicker в форме создания кампании

## Проблема

При открытии попапа "Создать кампанию" в консоли браузера возникала ошибка:

```
Uncaught (in promise) TypeError: Cannot read properties of undefined (reading 'hour')
```

Ошибка возникала в компоненте `el-time-picker` из Element Plus при попытке прочитать свойство 'hour' из undefined.

## Причина

Проблема заключалась в неправильной конфигурации компонента `el-time-picker`:

1. **Неправильная конфигурация**: В компоненте был указан `value-format="HH:mm"`, что означало, что компонент должен работать со строками
2. **Конфликт типов**: В `formData` поля были инициализированы как `null` (Date | null), но компонент ожидал строки
3. **Неправильная инициализация**: При инициализации формы значения не были корректно преобразованы

## Решение

### 1. Исправление конфигурации TimePicker

Убрали `value-format="HH:mm"` из конфигурации, чтобы компонент работал с объектами Date:

```vue
<!-- До исправления -->
<el-time-picker
  v-model="formData.workingHoursStart"
  format="HH:mm"
  value-format="HH:mm"  <!-- Убрали это -->
  placeholder="09:00"
  :clearable="false"
/>

<!-- После исправления -->
<el-time-picker
  v-model="formData.workingHoursStart"
  format="HH:mm"
  placeholder="09:00"
  :clearable="false"
/>
```

### 2. Правильная инициализация formData

Изменили инициализацию с `null` на корректные объекты Date:

```typescript
// До исправления
const formData = ref({
  // ... другие поля
  workingHoursStart: null as Date | null,
  workingHoursEnd: null as Date | null
})

// После исправления
const formData = ref({
  // ... другие поля
  workingHoursStart: timeStringToDate('09:00'),
  workingHoursEnd: timeStringToDate('18:00')
})
```

### 3. Утилитарные функции для работы с временем

Функции были перемещены выше в коде для правильной инициализации и улучшены:

```typescript
/**
 * Преобразует строку времени в объект Date
 * @param timeString - строка времени в формате "HH:mm"
 * @returns объект Date с установленным временем
 */
function timeStringToDate(timeString: string): Date {
  try {
    const [hours, minutes] = timeString.split(':').map(Number)
    const date = new Date()
    date.setHours(hours, minutes, 0, 0)
    return date
  } catch (error) {
    console.error('Ошибка парсинга времени:', error)
    // Возвращаем значение по умолчанию при ошибке
    const date = new Date()
    date.setHours(9, 0, 0, 0)
    return date
  }
}

/**
 * Преобразует объект Date в строку времени
 * @param date - объект Date или null
 * @returns строка времени в формате "HH:mm" или пустая строка
 */
function dateToTimeString(date: Date | null): string {
  if (!date || !(date instanceof Date) || isNaN(date.getTime())) return ''
  return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
}
```

### 4. Улучшенная валидация

Добавили проверку на корректность Date объектов:

```typescript
workingHoursStart: [
  { required: true, message: 'Укажите время начала работы', trigger: 'blur' },
  { 
    validator: (rule: any, value: any, callback: any) => {
      if (!value || !(value instanceof Date) || isNaN(value.getTime())) {
        callback(new Error('Некорректное время начала работы'))
      } else {
        callback()
      }
    }, 
    trigger: 'blur' 
  }
],
```

### 5. Правильная обработка данных для API

В `handleSubmit` данные корректно преобразуются из Date в строки для отправки на сервер:

```typescript
const submitData = {
  ...formData.value,
  audioFilePath: uploadedFilePath.value || formData.value.audioFilePath,
  workingHoursStart: dateToTimeString(formData.value.workingHoursStart),
  workingHoursEnd: dateToTimeString(formData.value.workingHoursEnd)
}
```

## Принцип работы Element Plus TimePicker

Согласно документации Element Plus:

- **Без `value-format`**: компонент работает с объектами Date
- **С `value-format`**: компонент работает со строками в указанном формате

Наш выбор: работать с объектами Date внутри компонента, конвертировать в строки только при отправке на сервер.

## Результат

После внесения изменений:

1. ✅ Ошибка "Cannot read properties of undefined (reading 'hour')" устранена
2. ✅ Компонент `el-time-picker` корректно отображает и обрабатывает время
3. ✅ Добавлена расширенная валидация времени
4. ✅ Корректная обработка данных для API
5. ✅ Улучшена отказоустойчивость при парсинге времени
6. ✅ Правильная инициализация формы

## Файлы, которые были изменены

- `frontend/src/components/CampaignForm.vue` - основные исправления

## Рекомендации по тестированию

1. **Создание кампании**: Проверьте создание новой кампании с различными значениями рабочих часов
2. **Редактирование кампании**: Убедитесь, что при редактировании время корректно загружается и сохраняется
3. **Валидация**: Проверьте, что валидация времени работает корректно
4. **Крайние случаи**: Протестируйте поведение при некорректных данных времени

Все исправления соответствуют официальной документации Element Plus и следуют лучшим практикам Vue.js. 