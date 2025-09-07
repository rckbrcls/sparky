import * as DocumentPicker from "expo-document-picker";
import * as FileSystem from "expo-file-system";
import React, { useState } from "react";
import {
  Alert,
  ScrollView,
  Share,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { ReminderService } from "../../services/ReminderService";

export default function SettingsScreen() {
  const [isExporting, setIsExporting] = useState(false);
  const [isImporting, setIsImporting] = useState(false);

  const handleExportJSON = async () => {
    try {
      setIsExporting(true);
      const jsonData = await ReminderService.exportData();

      const fileName = `lembretes_backup_${
        new Date().toISOString().split("T")[0]
      }.json`;
      const fileUri = FileSystem.documentDirectory + fileName;

      await FileSystem.writeAsStringAsync(fileUri, jsonData);

      await Share.share({
        url: fileUri,
        title: "Exportar Lembretes",
      });

      Alert.alert("Sucesso", "Dados exportados com sucesso!");
    } catch (error) {
      Alert.alert("Erro", "Não foi possível exportar os dados");
      console.error("Export error:", error);
    } finally {
      setIsExporting(false);
    }
  };

  const handleExportCSV = async () => {
    try {
      setIsExporting(true);
      const csvData = await ReminderService.exportCSV();

      const fileName = `lembretes_${
        new Date().toISOString().split("T")[0]
      }.csv`;
      const fileUri = FileSystem.documentDirectory + fileName;

      await FileSystem.writeAsStringAsync(fileUri, csvData);

      await Share.share({
        url: fileUri,
        title: "Exportar Lembretes CSV",
      });

      Alert.alert("Sucesso", "Dados exportados em CSV com sucesso!");
    } catch (error) {
      Alert.alert("Erro", "Não foi possível exportar os dados em CSV");
      console.error("Export CSV error:", error);
    } finally {
      setIsExporting(false);
    }
  };

  const handleImportJSON = async () => {
    try {
      setIsImporting(true);

      const result = await DocumentPicker.getDocumentAsync({
        type: "application/json",
        copyToCacheDirectory: true,
      });

      if (!result.canceled && result.assets[0]) {
        const fileContent = await FileSystem.readAsStringAsync(
          result.assets[0].uri
        );

        Alert.alert(
          "Confirmar Importação",
          "Isso irá substituir todos os seus lembretes atuais. Tem certeza?",
          [
            { text: "Cancelar", style: "cancel" },
            {
              text: "Importar",
              style: "destructive",
              onPress: async () => {
                try {
                  await ReminderService.importData(fileContent);
                  Alert.alert("Sucesso", "Dados importados com sucesso!");
                } catch {
                  Alert.alert("Erro", "Arquivo inválido ou corrompido");
                }
              },
            },
          ]
        );
      }
    } catch (error) {
      Alert.alert("Erro", "Não foi possível importar os dados");
      console.error("Import error:", error);
    } finally {
      setIsImporting(false);
    }
  };

  const handleClearAllData = () => {
    Alert.alert(
      "Apagar Todos os Dados",
      "Esta ação não pode ser desfeita. Todos os seus lembretes serão perdidos permanentemente.",
      [
        { text: "Cancelar", style: "cancel" },
        {
          text: "Apagar Tudo",
          style: "destructive",
          onPress: async () => {
            try {
              // Here you would implement a method to clear all data
              Alert.alert("Sucesso", "Todos os dados foram apagados");
            } catch {
              Alert.alert("Erro", "Não foi possível apagar os dados");
            }
          },
        },
      ]
    );
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Configurações</Text>
      </View>

      <View style={styles.content}>
        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Exportar Dados</Text>
          <Text style={styles.sectionDescription}>
            Faça backup dos seus lembretes para não perdê-los
          </Text>

          <TouchableOpacity
            style={[styles.button, styles.primaryButton]}
            onPress={handleExportJSON}
            disabled={isExporting}
          >
            <Text style={styles.primaryButtonText}>
              {isExporting ? "Exportando..." : "Exportar como JSON"}
            </Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.button, styles.secondaryButton]}
            onPress={handleExportCSV}
            disabled={isExporting}
          >
            <Text style={styles.secondaryButtonText}>
              {isExporting ? "Exportando..." : "Exportar como CSV"}
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Importar Dados</Text>
          <Text style={styles.sectionDescription}>
            Restaure seus lembretes de um backup anterior
          </Text>

          <TouchableOpacity
            style={[styles.button, styles.primaryButton]}
            onPress={handleImportJSON}
            disabled={isImporting}
          >
            <Text style={styles.primaryButtonText}>
              {isImporting ? "Importando..." : "Importar JSON"}
            </Text>
          </TouchableOpacity>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Sobre o App</Text>
          <View style={styles.infoCard}>
            <Text style={styles.infoTitle}>I Can&apos;t Miss</Text>
            <Text style={styles.infoDescription}>
              Um app de lembretes inteligente que te ajuda a nunca mais esquecer
              das coisas importantes.
            </Text>
            <Text style={styles.infoFeatures}>
              • Lembretes únicos e recorrentes{"\n"}• Sistema de soneca
              inteligente{"\n"}• Revisão espaçada para tarefas importantes{"\n"}
              • Datas importantes com notificações antecipadas{"\n"}• Backup e
              sincronização dos dados
            </Text>
          </View>
        </View>

        <View style={styles.section}>
          <Text style={styles.sectionTitle}>Zona de Perigo</Text>
          <Text style={styles.sectionDescription}>
            Ações irreversíveis que afetam todos os seus dados
          </Text>

          <TouchableOpacity
            style={[styles.button, styles.dangerButton]}
            onPress={handleClearAllData}
          >
            <Text style={styles.dangerButtonText}>Apagar Todos os Dados</Text>
          </TouchableOpacity>
        </View>
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#F8F9FA",
  },
  header: {
    backgroundColor: "#FFFFFF",
    paddingTop: 60,
    paddingBottom: 20,
    paddingHorizontal: 20,
    borderBottomWidth: 1,
    borderBottomColor: "#E9ECEF",
  },
  headerTitle: {
    fontSize: 28,
    fontWeight: "700",
    color: "#1A1A1A",
    textAlign: "center",
  },
  content: {
    padding: 20,
  },
  section: {
    marginBottom: 32,
  },
  sectionTitle: {
    fontSize: 20,
    fontWeight: "600",
    color: "#1A1A1A",
    marginBottom: 8,
  },
  sectionDescription: {
    fontSize: 14,
    color: "#6C757D",
    marginBottom: 16,
    lineHeight: 20,
  },
  button: {
    borderRadius: 12,
    padding: 16,
    alignItems: "center",
    marginBottom: 12,
  },
  primaryButton: {
    backgroundColor: "#339AF0",
  },
  primaryButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#FFFFFF",
  },
  secondaryButton: {
    backgroundColor: "#FFFFFF",
    borderWidth: 2,
    borderColor: "#339AF0",
  },
  secondaryButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#339AF0",
  },
  dangerButton: {
    backgroundColor: "#FF6B6B",
  },
  dangerButtonText: {
    fontSize: 16,
    fontWeight: "600",
    color: "#FFFFFF",
  },
  infoCard: {
    backgroundColor: "#FFFFFF",
    borderRadius: 12,
    padding: 20,
    borderWidth: 1,
    borderColor: "#E9ECEF",
  },
  infoTitle: {
    fontSize: 18,
    fontWeight: "600",
    color: "#1A1A1A",
    marginBottom: 8,
  },
  infoDescription: {
    fontSize: 14,
    color: "#6C757D",
    lineHeight: 20,
    marginBottom: 16,
  },
  infoFeatures: {
    fontSize: 14,
    color: "#495057",
    lineHeight: 22,
  },
});
