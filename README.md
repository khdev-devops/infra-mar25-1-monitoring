# Övervakning av server med alarm och metrics

En praktisk övning som visar ett enkelt exempel på övervakning av en EC2-instans med hjälp av AWS CloudWatch. Du kommer att:
- Skapa en EC2-instans med hjälp av OpenTofu
- Sätta rätt instansprofil för att möjliggöra SSM och CloudWatch Agent
- Aktivera detaljerad mätning av CPU, RAM och diskanvändning
- Skapa ett CloudWatch-alarm som triggar vid hög CPU-belastning
- Se på metrics och alarm via CloudWatch (utan att skapa dashboard)
- Testa alarmet genom att stressa instansen

## Förberedelser

1. Klona repo och navigera till projektmappen:
   ```bash
   git clone https://github.com/khdev-devops/infra-mar25-1-monitoring
   cd infra-mar25-1-monitoring
   ```

2. Installera OpenTofu i AWS CloudShell:
   ```bash
   ./tofu_install_and_init.sh
   ```

3. Skapa nyckel för SSH (om du inte redan har en):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/tofu-key -N ""
   ```

4. Skapa `terraform.tfvars`:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Redigera `terraform.tfvars`:
   - Ange din publika IP-adress (för att tillåta SSH från CloudShell eller egen dator).

5. Initiera och kör OpenTofu:
   ```bash
   tofu plan
   tofu apply
   ```

   Efter `apply` kommer du få ut den publika IP-adressen till din EC2-instans.

6. Gå till **EC2 > Instances > [din instans]** och sätt instansprofil (Actions > Security > Modify IAM role) till **"Student-Ec2GeneralExecutionProfile"**:
   - Detta krävs för att AWS Systems Manager (SSM) ska kunna kommunicera med instansen och för att CloudWatch Agent ska kunna skicka RAM/disk-metrics.

---

## Del 1: Aktivera metrics och alarm via AWS Console

### 1. Aktivera CloudWatch Agent via konsolen

1. Gå till **EC2 > Instances**
2. Markera din instans > **Actions > Monitor and troubleshoot > Configure CloudWatch Agent**
3. Klicka igenom guiden:
   - `Validate CloudWatch agent`: Klicka på **Install CloudWatch agent**
   - `Select configuration`: Kryssa i (den förvalda metric är rätt)
      - Memory
      - CPU
      - Disk
      - Kryssa för CPU, RAM och diskanvändning
   - Klicka **Complete** i slutet av guiden.

- Om steget `Validate SSM Agent` misslyckas:
   - SSHa till instansen och kör kommandot
      ```bash
      sudo systemctl restart amazon-ssm-agent
      ```

> Efter någon minut kommer metrics att börja synas i CloudWatch

### 2. Visa metrics i CloudWatch

1. Gå till **CloudWatch > Metrics**
2. Välj **CWAgent** och kika runt i de olika kategiorierna efter `mem_used_percent`, `cpu_usage_active` och `disk_used_percent` (path `/`) för instansen `mar25-opentofu-monitoring`.
4. Överst till höger under grafen – välj **Period: 1 minute**
5. Överst till höger:
  - Välj Local Timezone och senaste 15 minuterna.

---

## Del 2: Skapa alarm

1. Gå till **CloudWatch > Alarms > Create alarm**
2. Klicka på **Browse > EC2 > Per-Instance Metrics**
3. Välj din instans > cpu_usage_active
4. Välj:

      | Fält | Värde |
      |------|-------|
      | **Namespace** | `CWAgent` |
      | **Metric name** | `cpu_usage_active` |
      | **Statistic** | `Average` |
      | **Period** | `60 seconds` *(1 minut)* |
      | **Threshold type** | `Static` |
      | **Threshold value** | `70` |
      | **Condition** | `Greater than` |
      | **Datapoints to alarm** | `2 out of 2` |
      | **Missing data treatment** | `Treat missing data as ignore` |

      Förklaring:
      - **Period = 60 sekunder**: Varje datapunkt representerar 1 minut.
      - **Datapoints to alarm = 2 out of 2**: Två datapunkter i rad (dvs två minuter) måste vara över 70% för att alarmet ska gå till ALARM.
      - **Threshold = 70**: Den nivå vi vill övervaka.

5. Notification:
   - **Create new (SNS) topic**, ge det namnet `mar25-cpu-alarm`, och ange din e-post
      - AWS skickar ett bekräftelsemail – du måste klicka på länken för att ta emot larm
6. Add name and description:
   - Ge alarmet namnet `mar25-cpu-alarm`
7. Preview and create:
   - Klicka på **Create alarm**
8. Vänta till det skapade alarmets `State` blir `OK`.
---

## Del 3: Testa alarmet

1. SSH till din instans:
   ```bash
   ssh -i ~/.ssh/tofu-key ec2-user@<din-ip>
   ```

2. Installera stress-ng:
   ```bash
   sudo dnf install -y stress-ng
   ```

3. Starta CPU-belastning i 3 minuter:
   ```bash
   stress-ng --cpu 2 --timeout 180s
   ```

---

## Del 4: Övervaka alarm och metrics

1. Gå tillbaka till **CloudWatch > Metrics**:
   - Se hur CPU-mätvärdet stiger

2. Gå till **CloudWatch > Alarms**:
   - Se hur ditt alarm ändrar status till **"In Alarm"**
   - Klicka på alarmet för att se historik och graf

3. Bekräfta att du får e-postmeddelande

---

## Del 5: Rensa upp

Nu när du är klar med övningen, ta bort resurserna för att undvika kostnader.

1. Ta bort CloudWatch-alarmet: `mar25-cpu-alarm`

2. Ta bort SNS-topic och e-postprenumeration
	- Gå till **SNS > Topics**
	- Klicka på `mar25-cpu-alarm`
	- Gå till **Subscriptions** och:
	   - Ta bort prenumerationen (unsubscribe)
	- Gå tillbaka till **Topic overview** och klicka **Delete**

3. Ta bort EC2-instasen och relaterad infrastruktur skapad av OpenTofu:
   - I CloudSHell (i projektets katalog):
	```bash
	tofu destroy
	```
