-- Fix for PostgreSQL audit logging function
-- This fixes the "operator does not exist: jsonb - jsonb" error

CREATE OR REPLACE FUNCTION log_audit_action()
RETURNS TRIGGER AS $$
DECLARE
    changes_json JSONB := '{}';
    old_json JSONB;
    new_json JSONB;
    key TEXT;
    old_val JSONB;
    new_val JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO public.audit_log (table_name, record_id, action, new_values, created_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'INSERT', to_jsonb(NEW), auth.uid());
    ELSIF TG_OP = 'UPDATE' THEN
        -- Calculate changes manually to avoid jsonb - jsonb operator issue
        old_json := to_jsonb(OLD);
        new_json := to_jsonb(NEW);
        
        -- Compare each field
        FOR key IN SELECT jsonb_object_keys(new_json)
        LOOP
            old_val := old_json -> key;
            new_val := new_json -> key;
            
            -- If values are different, add to changes
            IF old_val IS DISTINCT FROM new_val THEN
                changes_json := changes_json || jsonb_build_object(key, jsonb_build_object('old', old_val, 'new', new_val));
            END IF;
        END LOOP;
        
        INSERT INTO public.audit_log (table_name, record_id, action, old_values, new_values, changes, created_by)
        VALUES (TG_TABLE_NAME, NEW.id, 'UPDATE', old_json, new_json, changes_json, auth.uid());
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO public.audit_log (table_name, record_id, action, old_values, created_by)
        VALUES (TG_TABLE_NAME, OLD.id, 'DELETE', to_jsonb(OLD), auth.uid());
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;
