import { format, parseISO } from "date-fns";
import { ptBR } from "date-fns/locale";
import React from "react";
import { Alert, StyleSheet, Text, TouchableOpacity, View } from "react-native";
import { Reminder } from "../database/database";
import { ReminderService } from "../services/ReminderService";

interface ReminderItemProps {
  reminder: Reminder;
  onRefresh: () => void;
}

export const ReminderItem: React.FC<ReminderItemProps> = ({
  reminder,
  onRefresh,
}) => {
  const getStatusColor = () => {
    switch (reminder.status) {
      case "overdue":
        return "#FF6B6B";
      case "completed":
        return "#51CF66";
      case "active":
        return "#339AF0";
      case "archived":
        return "#868E96";
      default:
        return "#339AF0";
    }
  };

  const getStatusText = () => {
    switch (reminder.status) {
      case "overdue":
        return "Atrasado";
      case "completed":
        return "Concluído";
      case "active":
        return "Ativo";
      case "archived":
        return "Arquivado";
      default:
        return "Ativo";
    }
  };

  const formatFireDate = () => {
    if (!reminder.nextFireAt) return "Sem data";

    try {
      const date = parseISO(reminder.nextFireAt);
      return format(date, "dd/MM/yyyy HH:mm", { locale: ptBR });
    } catch {
      return "Data inválida";
    }
  };

  const handleComplete = async () => {
    try {
      await ReminderService.completeReminder(reminder.id);
      onRefresh();
    } catch {
      Alert.alert("Erro", "Não foi possível marcar como concluído");
    }
  };

  const handleSnooze = async () => {
    try {
      await ReminderService.snoozeReminder(reminder.id);
      onRefresh();
    } catch {
      Alert.alert("Erro", "Não foi possível adiar o lembrete");
    }
  };

  const handleRemindLater = async () => {
    try {
      await ReminderService.remindLater(reminder.id);
      onRefresh();
    } catch {
      Alert.alert("Erro", "Não foi possível reagendar o lembrete");
    }
  };

  const handleArchive = async () => {
    Alert.alert(
      "Arquivar Lembrete",
      "Tem certeza que deseja arquivar este lembrete?",
      [
        { text: "Cancelar", style: "cancel" },
        {
          text: "Arquivar",
          style: "destructive",
          onPress: async () => {
            try {
              await ReminderService.archiveReminder(reminder.id);
              onRefresh();
            } catch {
              Alert.alert("Erro", "Não foi possível arquivar o lembrete");
            }
          },
        },
      ]
    );
  };

  const showActionSheet = () => {
    const options: Array<{
      text: string;
      onPress?: () => void;
      style?: "default" | "cancel" | "destructive";
    }> = [];

    if (reminder.status === "active" || reminder.status === "overdue") {
      options.push(
        { text: "Marcar como Concluído", onPress: handleComplete },
        { text: "Soneca", onPress: handleSnooze },
        { text: "Lembrar Depois", onPress: handleRemindLater },
        { text: "Arquivar", onPress: handleArchive, style: "destructive" }
      );
    }

    options.push({ text: "Cancelar", style: "cancel" });

    Alert.alert("Ações", "O que você gostaria de fazer?", options);
  };

  return (
    <TouchableOpacity style={styles.container} onPress={showActionSheet}>
      <View style={styles.header}>
        <Text style={styles.title}>{reminder.title}</Text>
        <View
          style={[styles.statusBadge, { backgroundColor: getStatusColor() }]}
        >
          <Text style={styles.statusText}>{getStatusText()}</Text>
        </View>
      </View>

      {reminder.notes && <Text style={styles.notes}>{reminder.notes}</Text>}

      <View style={styles.metadata}>
        {reminder.person && (
          <Text style={styles.metadataText}>👤 {reminder.person}</Text>
        )}
        {reminder.project && (
          <Text style={styles.metadataText}>📁 {reminder.project}</Text>
        )}
        {reminder.location && (
          <Text style={styles.metadataText}>📍 {reminder.location}</Text>
        )}
      </View>

      <View style={styles.footer}>
        <Text style={styles.fireDate}>⏰ {formatFireDate()}</Text>
        <Text style={styles.type}>{getTypeText(reminder.type)}</Text>
      </View>
    </TouchableOpacity>
  );
};

const getTypeText = (type: string) => {
  switch (type) {
    case "once":
      return "Única";
    case "recurring":
      return "Recorrente";
    case "by_person_project":
      return "Por Pessoa/Projeto";
    case "by_location":
      return "Por Localização";
    default:
      return type;
  }
};

const styles = StyleSheet.create({
  container: {
    backgroundColor: "#FFFFFF",
    borderRadius: 12,
    padding: 16,
    marginVertical: 8,
    marginHorizontal: 16,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.1,
    shadowRadius: 4,
    elevation: 3,
  },
  header: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "flex-start",
    marginBottom: 8,
  },
  title: {
    fontSize: 18,
    fontWeight: "600",
    color: "#1A1A1A",
    flex: 1,
    marginRight: 12,
  },
  statusBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  statusText: {
    fontSize: 12,
    fontWeight: "500",
    color: "#FFFFFF",
  },
  notes: {
    fontSize: 14,
    color: "#666666",
    lineHeight: 20,
    marginBottom: 12,
  },
  metadata: {
    flexDirection: "row",
    flexWrap: "wrap",
    marginBottom: 12,
  },
  metadataText: {
    fontSize: 12,
    color: "#888888",
    marginRight: 16,
    marginBottom: 4,
  },
  footer: {
    flexDirection: "row",
    justifyContent: "space-between",
    alignItems: "center",
  },
  fireDate: {
    fontSize: 14,
    color: "#339AF0",
    fontWeight: "500",
  },
  type: {
    fontSize: 12,
    color: "#888888",
    backgroundColor: "#F1F3F5",
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
});
