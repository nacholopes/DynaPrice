import SwiftUI
import CoreData

struct TriggerConfigView: View {
    let viewContext: NSManagedObjectContext
    @StateObject private var triggerManager: TriggerManager
    @State private var showingAddTrigger = false
    
    init(viewContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        _triggerManager = StateObject(wrappedValue: TriggerManager(context: viewContext))
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(triggerManager.triggers, id: \.id) { trigger in
                    TriggerRow(trigger: trigger, triggerManager: triggerManager, viewContext: viewContext)
                }
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let trigger = triggerManager.triggers[index]
                        triggerManager.deleteTrigger(trigger)
                    }
                }
            }
            .navigationTitle("Price Triggers")
            .toolbar {
                Button("Add Trigger") {
                    showingAddTrigger = true
                }
            }
            .sheet(isPresented: $showingAddTrigger) {
                AddTriggerView(viewContext: viewContext, triggerManager: triggerManager, isPresented: $showingAddTrigger)
            }
        }
    }
}

struct TriggerRow: View {
    @ObservedObject var trigger: PriceTrigger
    @State private var showingEditSheet = false
    let triggerManager: TriggerManager
    let viewContext: NSManagedObjectContext
    
    var body: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(trigger.name ?? "")
                        .font(.headline)
                    Spacer()
                    if trigger.active {
                        Text("Active")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    else {
                        Text("Inactive")
                            .foregroundColor(.red)
                            .font(.caption)
                        }
                }
                
                if let triggerType = trigger.triggerType {
                    switch triggerType {
                    case TriggerType.salesVolume.rawValue:
                        Text("When sales \(trigger.direction ?? "") by \(String(format: "%.0f", trigger.percentageThreshold))%")
                            .font(.subheadline)
                        Text("Over \(trigger.timeWindow) hours")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                    case TriggerType.timeBasedRule.rawValue:
                        Text("Time window: \(trigger.timeWindowStart):00 - \(trigger.timeWindowEnd):00")
                            .font(.subheadline)
                        if let days = trigger.daysOfWeek {
                            Text("Days: \(days)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                    case TriggerType.competitorPrice.rawValue:
                        Text("Competitor price threshold: \(String(format: "%.0f", trigger.percentageThreshold))%")
                            .font(.subheadline)
                        if let competitors = trigger.competitors {
                            Text("Monitoring: \(competitors)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                    default:
                        EmptyView()
                    }
                }
                
                Text("Suggest price change by \(String(format: "%.0f", trigger.priceChangePercentage))%")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingEditSheet) {
            AddTriggerView(
                viewContext: viewContext,
                triggerManager: triggerManager,
                isPresented: $showingEditSheet,
                editingTrigger: trigger
            )
        }
    }
}

struct AddTriggerView: View {
    let viewContext: NSManagedObjectContext
    let triggerManager: TriggerManager
    @Binding var isPresented: Bool
    var editingTrigger: PriceTrigger?
    
    @State private var selectedType: TriggerType = .salesVolume
    @State private var name = ""
    @State private var percentageThreshold = 25.0
    @State private var timeWindow: Double = 1
    @State private var priceChangePercentage = 10.0
    @State private var direction = "increase"
    @State private var isActive = true
    
    // Time-based trigger fields
    @State private var startHour = 9
    @State private var endHour = 17
    @State private var selectedDays: Set<Int> = []
    
    // Competitor trigger fields
    @State private var competitors: [String] = []
    @State private var newCompetitor = ""
    
    init(viewContext: NSManagedObjectContext,
         triggerManager: TriggerManager,
         isPresented: Binding<Bool>,
         editingTrigger: PriceTrigger? = nil) {
        self.viewContext = viewContext
        self.triggerManager = triggerManager
        self._isPresented = isPresented
        self.editingTrigger = editingTrigger
        
        // Initialize state with existing trigger values if editing
        if let trigger = editingTrigger {
            _name = State(initialValue: trigger.name ?? "")
            _selectedType = State(initialValue: TriggerType(rawValue: trigger.triggerType ?? "") ?? .salesVolume)
            _isActive = State(initialValue: trigger.active)
            _percentageThreshold = State(initialValue: trigger.percentageThreshold)
            _timeWindow = State(initialValue: Double(trigger.timeWindow))
            _priceChangePercentage = State(initialValue: trigger.priceChangePercentage)
            _direction = State(initialValue: trigger.direction ?? "increase")
            
            // Time-based fields
            _startHour = State(initialValue: Int(trigger.timeWindowStart))
            _endHour = State(initialValue: Int(trigger.timeWindowEnd))
            _selectedDays = State(initialValue: Set(
                (trigger.daysOfWeek ?? "")
                    .components(separatedBy: ",")
                    .compactMap { Int($0) }
            ))
            
            // Competitor fields
            _competitors = State(initialValue:
                (trigger.competitors ?? "")
                    .components(separatedBy: ",")
                    .filter { !$0.isEmpty }
            )
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Basic Settings")) {
                    TextField("Trigger Name", text: $name)
                    
                    if editingTrigger == nil {
                        Picker("Trigger Type", selection: $selectedType) {
                            ForEach(TriggerType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                    }
                    
                    Toggle("Active", isOn: $isActive)
                }
                
                switch selectedType {
                case .salesVolume:
                    salesVolumeSection
                case .competitorPrice:
                    competitorPriceSection
                case .timeBasedRule:
                    timeBasedSection
                case .stockLevel:
                    Text("Stock level triggers coming soon")
                }
                
                Section(header: Text("Price Change")) {
                    VStack {
                        Text("Adjust price by")
                        Slider(value: $priceChangePercentage, in: 5...50, step: 5)
                        Text("\(Int(priceChangePercentage))%")
                    }
                }
            }
            .navigationTitle(editingTrigger == nil ? "New Price Trigger" : "Edit Trigger")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    saveTrigger()
                    isPresented = false
                }
            )
        }
    }
    
    private var salesVolumeSection: some View {
        Section(header: Text("Sales Volume Settings")) {
            Picker("Direction", selection: $direction) {
                Text("Increase").tag("increase")
                Text("Decrease").tag("decrease")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            VStack {
                Text("Sales volume change threshold")
                Slider(value: $percentageThreshold, in: 5...100, step: 5)
                Text("\(Int(percentageThreshold))%")
            }
            
            VStack {
                Text("Time window")
                Slider(value: $timeWindow, in: 1...24, step: 1)
                Text("\(Int(timeWindow)) hours")
            }
        }
    }
    
    private var competitorPriceSection: some View {
        Section(header: Text("Competitor Settings")) {
            HStack {
                TextField("Add competitor", text: $newCompetitor)
                Button(action: {
                    if !newCompetitor.isEmpty {
                        competitors.append(newCompetitor)
                        newCompetitor = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                }
            }
            
            ForEach(competitors, id: \.self) { competitor in
                Text(competitor)
            }
            .onDelete { indexSet in
                competitors.remove(atOffsets: indexSet)
            }
            
            VStack {
                Text("Price difference threshold")
                Slider(value: $percentageThreshold, in: 5...50, step: 5)
                Text("\(Int(percentageThreshold))%")
            }
        }
    }
    
    private var timeBasedSection: some View {
        Section(header: Text("Time Settings")) {
            HStack {
                Text("Start Hour")
                Picker("", selection: $startHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
            }
            
            HStack {
                Text("End Hour")
                Picker("", selection: $endHour) {
                    ForEach(0..<24) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
            }
            
            ForEach(1..<8) { day in
                Toggle(Calendar.current.weekdaySymbols[day-1], isOn: Binding(
                    get: { selectedDays.contains(day) },
                    set: { isSelected in
                        if isSelected {
                            selectedDays.insert(day)
                        } else {
                            selectedDays.remove(day)
                        }
                    }
                ))
            }
        }
    }
    
    private func saveTrigger() {
        if let existingTrigger = editingTrigger {
            // Update existing trigger
            existingTrigger.name = name
            existingTrigger.active = isActive
            existingTrigger.percentageThreshold = percentageThreshold
            existingTrigger.priceChangePercentage = priceChangePercentage
            
            switch selectedType {
            case .salesVolume:
                existingTrigger.timeWindow = Int16(timeWindow)
                existingTrigger.direction = direction
                
            case .timeBasedRule:
                existingTrigger.timeWindowStart = Int16(startHour)
                existingTrigger.timeWindowEnd = Int16(endHour)
                existingTrigger.daysOfWeek = selectedDays.map(String.init).joined(separator: ",")
                
            case .competitorPrice:
                existingTrigger.competitors = competitors.joined(separator: ",")
                
            case .stockLevel:
                break
            }
            
            try? viewContext.save()
            triggerManager.fetchTriggers()
        } else {
            // Create new trigger based on type
            switch selectedType {
            case .salesVolume:
                triggerManager.addNewTrigger(
                    name: name,
                    triggerType: selectedType.rawValue,
                    active: isActive,
                    percentageThreshold: percentageThreshold,
                    timeWindow: Int16(timeWindow),
                    priceChangePercentage: priceChangePercentage,
                    direction: direction
                )
                
            case .competitorPrice:
                triggerManager.addNewCompetitorTrigger(
                    name: name,
                    competitorNames: competitors,
                    thresholdPercentage: percentageThreshold,
                    priceChangePercentage: priceChangePercentage
                )
                
            case .timeBasedRule:
                triggerManager.addNewTimeTrigger(
                    name: name,
                    startHour: startHour,
                    endHour: endHour,
                    daysOfWeek: selectedDays,
                    priceChangePercentage: priceChangePercentage
                )
                
            case .stockLevel:
                break
            }
        }
    }
}
